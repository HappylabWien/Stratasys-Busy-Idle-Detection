require 'state_machine'
require 'socket'
require 'timeout'
require_relative 'errors'

# A client for Statasys Dimension 3D printers
# Mimics the driver behaviour for querying status and
# sending jobs to the printer.
class DriverClient

  attr_accessor :fileName_receive, :fileSize_receive, :fileData_receive

  # Protocol steps
  state_machine :protocolState, :initial => :idle do
    event :query_status do
      transition [:idle] => :getFile
    end

    after_transition :idle => :getFile, :do => :send_getFile

    event :server_reply_sendFile do
      transition :getFile  => :sendFile_ok
    end

    event :server_reply_size do
      transition :sendFile_ok => :size_ok
    end

    event :server_reply_data do
      transition :size_ok => :data_transferred
    end

    event :server_fail do
      transition [:getFile, :sendFile_ok, :size_ok] => :failed
    end
  end

  def initialize(server, port)
    @fileName_receive = ''
    @fileSize_receive = 0
    @fileData_receive = ''
    @server = server
    @port = port
    @timeout_reply = 30
    @timeout_connect = 30
    # connect to server
    @sock = begin
      Timeout::timeout( @timeout_connect ) { TCPSocket.open( @server, @port ) }
    rescue StandardError, RuntimeError => ex
      #server_fail
      raise "cannot connect to printer server: #{ex}"
    end
    super() # NOTE: This *must* be called, otherwise states won't get initialized
  end

  def send_getFile
    query_status_transition
    protocolState_events
    protocolState_transitions
    # send out request for printer status file
    @sock.write(packBytes("GetFile", 64))
    @sock.write(packBytes("status.sts", 64)+packBytes("NA", 64))

    # server must reply with SendFile and file name
    IO.select([@sock], nil, nil, @timeout_reply) or fail TimeoutError
    if getServerData(64).unpack('Z64') != 'SendFile'
      #server_fail
      #raise "printer server would not send file: #{ex}"
    end

    @fileName_receive = getServerData(64).unpack('Z*')

  end

  def sendFile_ok
    # send out ready for receive file size
    @sock.write(packBytes("OK", 64))
    IO.select([@sock], nil, nil, @timeout_reply) or fail TimeoutError
    # server must reply with file size
    @fileSize_receive = Integer(getServerData(64).unpack('Z*').join())
  end

  def size_ok
    # send out ready for receive file data
    @sock.write(packBytes("OK", 64))
    # server must reply with file data in packages sized max. 1460 bytes
    @fileData_receive=""
    dataleft = @fileSize_receive
    IO.select([@sock], nil, nil, @timeout_reply) or fail TimeoutError
    while dataleft > 0
      @fileData_receive += getServerData(1460)
      dataleft -= 1460
    end
    @fileData_receive
  end

  def getServerData(dataLength)
    IO.select([@sock], nil, nil, @timeout_reply) or fail TimeoutError
    data = begin
      Timeout::timeout( @timeout_reply ) { @sock.recv(dataLength) }
    rescue StandardError, RuntimeError => ex
      #server_fail
      raise "no data from server: #{ex}"
    end
  end

  def data_transferred
    # send out data transferred
    @sock.write(packBytes("Transferred: #{@fileSize_receive}", 64))
    #idle
  end

  def closeConnection
    @sock.close
  end

  def packBytes(string, size)
    string.concat("\0" * (size - string.size))
  end
end