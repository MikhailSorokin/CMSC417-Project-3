require 'socket' #Required import to allow server connection 
require 'thread'

$port = nil
$hostname = nil

# ----------------------- Loop methods -----------------------#
class Neighbor
	attr_accessor :name, :cost

	def initialize(name, cost)
		@name = name
		@cost = cost
	end
	
	def ==(other)
		self.name == other
	end
	
	def to_s
		"#{name};#{cost},"
	end

end

# ----------------- Classes ------------------ #

def listeningloop()
	$server = TCPServer.new $port
	loop do
		Thread.fork($server.accept) do |clientSocket|
			puts "Accepting connection"
			$semaphore.synchronize {
				$serverSockets.push(clientSocket)
			}
		end
	end
end

def receivingloop()
	loop do
		$semaphore.synchronize {
			$serverSockets.each do |servSocket|
				STDOUT.puts "Receiving a message"
			  	ready = IO.select([servSocket])
	    		readable = ready[0] #0 is sockets for reading

	    		readable.each do |socket|
		            if socket == servSocket
		                buf = socket.recv(1024)
		                if buf.length == 0
		                    STDOUT.puts "The payload exceeds 1024 bytes."
		                else
		                	$internalMsgQueue.push(buf)
		                end
		            end
	            end
			end
		}
	end
end

#Need to parse messages and clear buffer as messages are read
def msgHandler()
	loop do
		$semaphore.synchronize {
			if !$internalMsgQueue.empty?
				str = $internalMsgQueue.pop
				STDOUT.puts "#{$hostname} handling this message: #{str}"
				args = str.split(" ")
				cmd = args[0]
				case (cmd)		
				#Acknowledgements
				when "APPLYEDGE"; handleEntryAdd(args[1], args[2])
				when "LSA"; receiveUpdatedNeighbors(args[1], args[2], args[3])
				else STDOUT.puts "ERROR: INVALID COMMAND \"#{cmd}\""
				end
			end
		}

		if($clock_val > $update_time)
			$update_time = $clock_val + $updateInterval

			performDijkstra()
		end
	end
end

def receiveUpdatedNeighbors(origName, origSeqNum, neighbors)
	#Update the cost of the neighbors here with the sequence number
	STDOUT.puts "#{$hostname} received these neighbors: #{neighbors}"
	neighborGroup = neighbors.split(",")

	if(!$graphInfo.has_key?(origName) || $graphInfo[origName][0] < origSeqNum.to_i)
		$graphInfo[origName] = Array.new()
		$graphInfo[origName][0] = origSeqNum.to_i
		$graphInfo[origName][1] = Array.new()
		neighborGroup.each do |neighbor_string|
			neighborArr = neighbor_string.split(";")
			neighborName = neighborArr[0]
			neighborCost = neighborArr[1]

			$graphInfo[origName][1].push(Neighbor.new(neighborName, neighborCost))
		end

		# We should flood the LSA we just processed
	end
end

def createOwnLSA()
	message = "LSA #{$hostname} #{$clock_val.to_s} "
	str = ""
	$neighbors.each do |neighbor|
		message << neighbor.to_s
	end
	message.chop! #Remove the last character, which will be a space
	puts "created LSA: #{message}"

	floodMessage(message)
end

def floodMessage(message)
	$neighbors.each do |neighbor|
		puts "flooding to #{neighbor.name}"
		if $nodeToSocket.has_key?(neighbor.name)
			$semaphore.synchronize {
				$nodeToSocket[neighbor.name].write(message)
			}
		end
	end
end

#DIJKSTRA
def performDijkstra()
	#We have the neighbors, so just initialize all distances to Infinity
	nodesToDistance = {}
	nodesToPrevious = {}

	nodeQueue = []
	$nodeToPort.each do |node, port|
		nodesToDistance[node] = Float::INFINITY
		nodeQueue.push(node)
	end

	nodesToDistance[$hostname] = 0

	while !nodeQueue.empty?
		#now use the neighbors array to see what is min distance
		minCost = Float::INFINITY
		vertexToRemove = nil

		nodeQueue.each do |node|
			if nodesToDistance[node] <= minCost
				minCost = nodesToDistance[node]
				vertexToRemove = node
			end
		end
		nodeQueue.delete(vertexToRemove)
		# Graph info is a mapping from node name to that node's neighbor information
		# A two element array contains the node's neighbor information
		# the first element is the sequence number which Dijkstra's ignores
		# The second element is an array of Neighbor class items corresponding to that node's neighbors
		# We are iterating over vertexToRemove's neighbors, not our own.
		if ($graphInfo.has_key?(vertexToRemove))
			$graphInfo[vertexToRemove].at(1).each do |othersNeighbor| 
				altDist = nodesToDistance[vertexToRemove] + othersNeighbor.cost

				if currDist < nodesToDistance[othersNeighbor.name].cost
					nodesToDistance[othersNeighbor.name] = currDist
					nodesToPrevious[othersNeighbor.name] = vertexToRemove
				end
			end	
		end
	end

	# We have the cost to travel to all other nodes and also the previous node in their path.
	# We want to find the next hop from us, the source node, and then assign that to our routing table.
	$rtable.clear
	nodesToPrevious.each do |node, prev|
		puts "creating rtable entry for  #{node}"
		if(prev == $hostname) # this means that the previous node is ourselves, so this node is a neighbor and is its own nexthop
			$rtable.push(new RoutingInfo($hostname, node, node, nodesToDistance[node]))
		else
			nextHop = nodesToPrevious[prev]
			#TODO - need neighbors.name I Believe
			while(!$neighbors.include?(nextHop))
				nextHop = nodesToPrevious[prev]
			end
			$rtable.push(new RoutingInfo($hostname, node, nextHop, nodesToDistance[node]))
		end
	end

	createOwnLSA()
end
	
	
# -------------- Helpers to do stuff to neighbors ----------------------- $
def handleEntryAdd(destNode, srcIP)
	clientSocket = TCPSocket.new(srcIP, $nodeToPort[destNode])
	$semaphore.synchronize {
		$nodeToSocket[destNode] = clientSocket
	}
	$neighbors.push(Neighbor.new(destNode, 1))
end

# Handles deleting entries from the table - ASYMMETRIC
def handleEntryDelete(destNode)
	$neighbors.delete_if {|n| n.name == destNode}
end

#Handles updating edge costs on the table
def handleEntryUpdate(destNode, newcost)
	i = $neighbors.index{|n| n.name == destNode}
	$neighbors[i].cost = newcost
end