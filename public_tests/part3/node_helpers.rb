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
		"#{name};#{cost}"
	end

end

# ----------------- Classes ------------------ #

def listeningloop()
	$server = TCPServer.new $port
	loop do
		Thread.fork($server.accept) do |clientSocket|
			$serverSockets.push(clientSocket)
		end
	end
end

def receivingloop()
	loop do
		if($serverSockets.length > 0)
		  	ready = IO.select($serverSockets)
    		readable = ready[0] #0 is sockets for reading

    		readable.each do |socket|
                buf = socket.recv(2048)
                if buf.length == 0
                    #STDOUT.puts "The payload exceeds 1024 bytes."
                else
                	buf.chop! #Remove the last character, which should be `
                	msgs = buf.split("`")
                	msgs.each do |msg|
                		$internalMsgQueue.push(msg)
                	end
                end
            end

            readable.clear
		end
	end
end

#Need to parse messages and clear buffer as messages are read
def msgHandler()
	loop do
		if (!$internalMsgQueue.empty?)
			str = $internalMsgQueue.pop
			args = str.split(" ")
			cmd = args[0]

			case (cmd)
				when "APPLYEDGE"; handleEntryAdd(args[1], args[2])
				when "LSA"; handleLSA(args[1], args[2], args[3], args[4])

				when "MSG"; readMessage(args[1], args[2], args[3..-1])

				when "PING"; readPing(args[1], args[2], args[3])
				when "PONG"; readPong(args[1], args[2], args[3])

				when "FORWARDROUTE"; readRoute(args[1], args[2], args[3], args[4], args[5])
				when "BACKROUTE"; endRoute(args[1], args[2], args[3], args[4], args[5])
					
				else STDOUT.puts "ERROR: INVALID COMMAND \"#{cmd}\""
			end
		end
	end
end

def dijkstras()
	loop do
		if($clock_val > $update_time)
			$update_time = $clock_val + $updateInterval

			createOwnLSA()
			performDijkstra()
		end
	end
end

def handleLSA(origName, origSeqNum, origChange, neighbors)
	#Update the cost of the neighbors here with the sequence number
	neighborGroup = neighbors.split(",")

	if(!$graphInfo.has_key?(origName) || $graphInfo[origName][0] < origSeqNum.to_i)
		if (origChange.to_i == 0 && $graphInfo.has_key?(origName))
			$graphInfo[origName][0] = origSeqNum.to_i
		else
			$network_change = 1
			$graphInfo[origName] = Array.new()
			$graphInfo[origName][0] = origSeqNum.to_i
			$graphInfo[origName][1] = Array.new()
			neighborGroup.each do |neighbor_string|
				neighborArr = neighbor_string.split(";")
				neighborName = neighborArr[0]
				neighborCost = neighborArr[1].to_i

				$graphInfo[origName][1].push(Neighbor.new(neighborName, neighborCost))
			end
		end

		floodMessage("LSA #{origName} #{origSeqNum} #{origChange} #{neighbors}`")
	end
end

def createOwnLSA()
	message = "LSA #{$hostname} #{$seq_val.to_s} #{$local_change} "
	$local_change = 0
	$seq_val = $seq_val + 1;
	str = ""
	$neighbors.each do |neighbor|
		message << "#{neighbor.to_s},"
	end
	message.chop! #Remove the last character, which will be a space

	floodMessage("#{message}`")
end

def floodMessage(message)
	$neighbors.each do |neighbor|
		if $nodeToSocket.has_key?(neighbor.name)
			$nodeToSocket[neighbor.name].write(message)
		end
	end
end

#DIJKSTRA
def performDijkstra()
	if($local_change == 0 && $network_change == 0)
		return
	end
	#We have the neighbors, so just initialize all distances to Infinity
	nodesToDistance = {}
	nodesToPrevious = {}

	nodeQueue = []
	$nodeToPort.each do |node, sock|
		nodesToDistance[node] = Float::INFINITY
		nodeQueue.push(node)
	end

	nodesToDistance[$hostname] = 0
	$rtable.clear
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
		if($graphInfo.has_key?(vertexToRemove))
			name = $graphInfo[vertexToRemove] 
			$graphInfo[vertexToRemove].at(1).each do |othersNeighbor| 
				altDist = nodesToDistance[vertexToRemove] + othersNeighbor.cost
				if altDist < nodesToDistance[othersNeighbor.name]
					nodesToDistance[othersNeighbor.name] = altDist
					if(vertexToRemove == $hostname)
						nodesToPrevious[othersNeighbor.name] = othersNeighbor.name
					else
						nodesToPrevious[othersNeighbor.name] = nodesToPrevious[vertexToRemove]
					end
					#STDOUT.puts nodesToPrevious[othersNeighbor.name]
				end
			end
		end

		#Problem is that n4 never has a nodesToPrevious array set for it on its own machine

		if(vertexToRemove != $hostname && nodesToDistance[vertexToRemove] != Float::INFINITY)
			prev = nodesToPrevious[vertexToRemove]
			$rtable.push(RoutingInfo.new(vertexToRemove, nodesToPrevious[vertexToRemove], nodesToDistance[vertexToRemove]))
		end
		
	end
	$network_change = 0
end

# -------------- Messages, Pings, and Traceroutes ----------------------- #

def relayMessage(nextHop, message)
	STDOUT.flush
	STDOUT.puts "#{nextHop} and Messagess #{message}"
	STDOUT.flush

	if $nodeToSocket.has_key?(nextHop)
		$nodeToSocket[nextHop].write(message)
		return true
	else
		return false
	end
end

def writeMessage(dst, msgArr)
	# The main loop split the message by ' ' characters. We should add those back in?
	msg = "MSG #{dst} #{$hostname} "
	msgArr.each do |word|
		msg << "#{word} "
	end
	msg.chop!

	# TODO - If msg.length > $maxPayload we need to fragment the payload over several messages.
	if(!relayMessage(dst, msg))
		STDOUT.puts "SENDMSG ERROR: HOST UNREACHABLE"
	end
end


def readMessage(dst, src, msgArr)
	if(dst == $hostname)
		# We are the destination and should read the message
		# TODO - handle message fragments to reconstruct original payload
		msg = ""

		msgArr.each do |word|
			msg << "#{word} "
		end
		msg.chop!

		# Do we output to console? Also, verify it's SENDMSG and not SNDMSG or something like that.
		STDOUT.puts "SENDMSG: [#{src}] -- > [#{msg}]"
	else
		msg = "MSG #{dst} #{src} "

		msgArr.each do |word|
			msg << "#{word} "
		end
		msg.chop!

		# If the payload needed to be fragmented, the src node would have done so, so we don't have to fragment here.
		relayMessage(dst, msg)
	end
end

# ------------------------------ PING/PONG ------------------------------ #
def writePing(dst, seqNum)
	i = $rtable.index{|n| n.dst == dst}
	message = "PING #{dst} #{$hostname} #{seqNum}`"
	if (i != nil && relayMessage($rtable[i].nextHop, message))
		pm = PingMessage.new(dst, seqNum, $clock_val)
		$pingQueue.push(pm)
		
		Thread.new() {
			sleep($pingTimeout)
		    if($pingQueue.pop != nil)
		    	STDOUT.puts "good PING ERROR: HOST UNREACHABLE"
		    end
		}
	else
		STDOUT.puts "bad PING ERROR: HOST UNREACHABLE"
	end
end

def readPing(dst, src, seqNum)
	if(dst == $hostname)
		nextMsg = "PONG #{dst} #{src} #{seqNum}`"
		i = $rtable.index{|n| n.dst == src}
		if (i != nil && relayMessage($rtable[i].nextHop, nextMsg))

		end
	else
		nextMsg = "PING #{dst} #{src} #{seqNum}`"
		i = $rtable.index{|n| n.dst == dst}
		if (i != nil && relayMessage($rtable[i].nextHop, nextMsg))
			
		end
	end
end	

def readPong(dst, src, seqNum)
	if (src == $hostname)
		finalPong(dst,seqNum)
	else
		nextMsg = "PONG #{dst} #{src} #{seqNum}`"
		i = $rtable.index{|n| n.dst == src}
		if (i != nil && relayMessage($rtable[i].nextHop, nextMsg))
			
		end
	end
end	

def finalPong(dst, seqNum)
	STDOUT.flush
	if !$pingQueue.empty?
		pm = $pingQueue.pop
		rtt = $clock_val - pm.time.to_i()
		STDOUT.puts "#{seqNum} #{dst} #{rtt}"
		STDOUT.flush
	end
end

# ---------------------------- Trace Route -------------------------------- #
class HopMessage
	attr_accessor :hopCount, :src, :timeToNode

	def initialize(hopCount, src, timeToNode)
		@hopCount = hopCount
		@src = src
		@timeToNode = timeToNode
	end

	def to_s
		"#{hopCount} #{src} #{timeToNode}"
	end
end

def startRoute(dst)
	i = $rtable.index{|n| n.dst == dst}
	message = "FORWARDROUTE #{dst} 0 #{$hostname} #{$clock_val} 0`"
	if (i != nil && relayMessage($rtable[i].nextHop, message))
		Thread.new(){
			sleep($pingTimeout)
		    if($receivedFinalMessage == 0)
		    	STDOUT.puts "#{$pingTimeout} ON #{$allTraceRouteInfo.length}"
		    end
		}
	else
    	STDOUT.puts "#{$pingTimeout} ON #{$allTraceRouteInfo.length}"
	end
end

#I want to read a route and then send one back to destination immediately
#So we would write two messages
def readRoute(dst, hopCount, src, lastTime, finBool)
	#Send a message forward...
	STDOUT.puts "GOT TO HERE"
	STDOUT.flush
	
	if(dst == $hostname)
		#When I have arrived at destination, JUST keep going back, no more forward
		#Messages
		nextMsg = "BACKROUTE #{hopCount} #{newHopCount} #{src} #{lastTime} 1`"
		i = $rtable.index{|n| n.dst == src}
		if i == nil
			#STDOUT.puts "Nil index"
		else
			prevHop = $rtable[i].nextHop	
			relayMessage(prevHop, nextMsg)
		end
	else
		elapsedTime = lastTime + $clock_val
		newHopCount = hopCount.to_i() + 1
		nextMsg = "FORWARDROUTE #{dst} #{newHopCount} #{src} #{elapsedTime} 0`"
		i = $rtable.index{|n| n.dst == dst}
		nextHop = $rtable[i].nextHop
		relayMessage(nextHop, nextMsg)

		#Send a message backwards...
		nextMsg = "BACKROUTE #{hopCount} #{newHopCount} #{src} #{lastTime} 0`"
		i = $rtable.index{|n| n.dst == src}
		if i == nil
			#STDOUT.puts "Nil index"
		else
			prevHop = $rtable[i].nextHop	
			relayMessage(prevHop, nextMsg)
		end

		STDOUT.puts "In read.."
		STDOUT.flush
	end
end	

def readEnd(dst, hopCount, src, timeToNode, reachedEnd)
	if (src == $hostname)
		finalTraceRead(hopCount, src, timeToNode, reachedEnd)
	else
		#Else, need to keep going back to find the source node
		nextMsg = "BACKROUTE #{dst} #{hopCount} #{src} #{timeToNode} 0`"
		i = $rtable.index{|n| n.dst == src}
		if i == nil
			#STDOUT.puts "Nil index"
		else
			prevHop = $rtable[i].nextHop	
			relayMessage(prevHop, nextMsg)
		end
	end
end	

#Once I have received every single TraceRoute information, I want to 
#make sure I have reached the destination node and came back, and 
#would print ALL of the route information from my current starting place
def finalTraceRead(hopCount, src, timeToNode, reachedEnd)
	#10 is the max hop count - according to specs, make sure it doesn't exceed 
	#that or we would be going for  a while
	if (reachedEnd == 0 && hopCount < 10)
		$allTraceRouteInfo.push(HopMessage.new(hopCount, src, timeToNode))
		#STDOUT.puts "#{$allTraceRouteInfo}"
	else
		($allTraceRouteInfo.sort {|x,y| x.hopCount <=> y.hopCount}).each do |entry|
			STDOUT.puts("#{entry}")
		end
		STDOUT.flush
		$receivedFinalMessage = 1
	end
end
	
# -------------------- Helpers to do stuff to neighbors --------------------- #
def handleEntryAdd(destNode, srcIP)
	clientSocket = TCPSocket.new(srcIP, $nodeToPort[destNode])
	$nodeToSocket[destNode] = clientSocket
	$rtable.push(RoutingInfo.new(destNode, destNode, 1))
	$local_change = 1
	$neighbors.push(Neighbor.new(destNode, 1))
end

# Handles deleting entries from the table - ASYMMETRIC
def handleEntryDelete(destNode)
	$neighbors.delete_if {|n| n.name == destNode}
	$local_change = 1
end

#Handles updating edge costs on the table
def handleEntryUpdate(destNode, newcost)
	i = $neighbors.index{|n| n.name == destNode}
	$neighbors[i].cost = newcost
	$local_change = 1
end