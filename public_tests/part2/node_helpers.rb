require 'socket' #Required import to allow server connection 

$port = nil
$hostname = nil
$server = nil

# ----------------------- Loop methods -----------------------#
def listeningloop()
	STDOUT.puts "LISTENING"
	$server = TCPServer.new $port
	loop do
		Thread.fork($server.accept) do |clientSocket|
			$socketsArray.push(clientSocket)
		end
	end
end

def receivingloop()
	loop do
		$socketsArray.each do |servSocket|
		  	ready = IO.select([servSocket])
    		readable = ready[0] #0 is sockets for reading

    		readable.each do |socket|
	            if socket == servSocket
	                buf = socket.recv(1024)
	                if buf.length == 0
	                    STDOUT.puts "The connection is dead. Try again. Exit."
	                    exit(1)
	                else
            			$semaphore.synchronize {
							$socketBuf[socket] = buf
						}
	                end
	            end
            end
		end
	end
end

#Need to parse messages and clear buffer as messages are read
def msgHandler()
	loop do
		$semaphore.synchronize {
			$socketBuf.each do |socket, str|
				str = str.strip()
				args = str.split(" ")
				cmd = args[0]
				destNode = args[1]
				case (cmd)		
				#Acknowledgements
				when "APPLYEDGE"; handleEntryAdd(socket,destNode)
				else STDOUT.puts "ERROR: INVALID COMMAND \"#{cmd}\""
				end
			end
		}

	end
end
	
# -------------- Helpers to do stuff to tables ----------------------- $
def handleEntryAdd(socket, destNode)
	if(!addtotable(destNode))
		STDOUT.puts "ERROR: INVALID ACKNOWLEDGEMENT"
	end
	socket.write("APPLYEDGE" << " " << $hostname)

	#TODO - Need to fix this
	$socketBuf.delete(socket)
end

def addtotable(node)
	# You know, I'm not sure this is even necessary. I think we could assume that addtotable is only called on new destinations.
	if $rtable.has_key?(node)
		return false
	else
		$rtable[node] = RoutingInfo.new($hostname, node, node, 1)
		return true
	end
end

# Handles deleting entries from the table - ASYMMETRIC
def handleEntryDelete(destNode)
	if(!deleteFromTable(destNode))
		STDOUT.puts "ERROR: INVALID ACKNOWLEDGEMENT"
	end
end

def deleteFromTable(node)
	#Only delete one way
	if $rtable.has_key?(node)
		$rtable.delete(node)
		return true
	else
		return false
	end
end

#Handles updating edge costs on the table
def handleEntryUpdate(destNode, newcost)
	if(!canUpdateTable(destNode, newcost))
		STDOUT.puts "ERROR: INVALID ACKNOWLEDGEMENT"
	end
end

def canUpdateTable(node, newcost)
	#Only update one way
	if $rtable.has_key?(node)
		$rtable[node].distance = newcost
		return true
	else
		return false
	end
end