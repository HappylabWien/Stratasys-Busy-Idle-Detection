require_relative 'driver_client'
require 'net/ping'

# printer settings
host='192.168.1.32' # Elite
# host='192.168.1.31' # BST
port=53742

# prepare pinging printer
printerping = Net::Ping::TCP.new(host)

while true do
  #TODO loop found entries
  begin
    # ping printer
    p printerping.ping?
    # open client connection
    client = DriverClient.new(host, port)
    # get status file
    filename = client.send_getFile
    puts "Server file name: #{filename}"
    filesize = client.sendFile_ok
    puts "Server file size #{filesize}"
    filedata = client.size_ok
    puts "Server file data #{filedata}"
    client.data_transferred
    client.closeConnection
  rescue
    filedata="Off"
  end

  puts filedata

  sleep 60 # TODO get from command line
end
