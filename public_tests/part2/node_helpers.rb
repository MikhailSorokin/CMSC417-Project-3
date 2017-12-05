require 'socket' #Required import to allow server connection 
require 'thread'

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
		if $internalMsgQueue.empty? != nil
			incoming = $internalMsgQueue.pop
			str = incoming.str.strip()
			args = str.split(" ")
			cmd = args[0]
			case (cmd)		
			#Acknowledgements
			when "APPLYEDGE"; handleEntryAdd(socket,args[1])
			when "LSA";
			else STDOUT.puts "ERROR: INVALID COMMAND \"#{cmd}\""
			end
			
			if($clock_val > $update_time)
				$update_time = $clock_val + $updateInterval
				
				performDijkstra()
			end
		end
	end
end

#DIJKSTRA
def performDijkstra()
	#We have the neighbors, so just initialize all distances to Infinity
	nodesToDistance = {}

	nodeQueue = []

	$neighbors.each do |neighbor|
		nodesToDistance[neighbor] = Float::INFINITY
		nodeQueue.push(neighbor)
	end

	nodesToDistance[$hostname] = 0
	nodeQueue.push($hostname)

	while nodeQueue.empty? != nil
		#now use the neighbors array to see what is min distance
		minCost = Float::INFINITY
		vertexToRemove = nil

		nodesToDistance.each do |node, cost|
			if cost <= minCost
				minCost = cost
				vertexToRemove = node
			end
		end

		currentVertex = nodeQueue.remove(vertexToRemove)

		nodeQueue.each do |neighborNode|
			currDist = currentVertex + $neighbors[neighborNode].cost

			if currDist < $neighbors[neighborNode].cost
				nodesToDistance[neighborNode] = currDist
				#TODO - Path
			end
		end	
	end
end
	
# -------------- Helpers to do stuff to tables ----------------------- $
def handleEntryAdd(socket, destNode)
	$neighbors.push(Neighbor.new(destNode, socket, 1))
	socket.write("APPLYEDGE" << " " << $hostname)
end

# Handles deleting entries from the table - ASYMMETRIC
def handleEntryDelete(destNode)
	$neighbors.delete_if {|n| n.name == destNode}
end

#Handles updating edge costs on the table
def handleEntryUpdate(destNode, newcost)
	if(!canUpdateTable(destNode, newcost))
		STDOUT.puts "ERROR: INVALID ACKNOWLEDGEMENT"
	end
end

def canUpdateTable(node, newcost)
	#Only update one way
	$neighbors[node].cost = newcost
end
