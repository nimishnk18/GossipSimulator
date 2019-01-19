defmodule Assignment2 do
  use GenServer

  @moduledoc """
  Documentation for Assignment2.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Assignment2.hello()
      :world

  """
  def start() do
    args = System.argv()

    if(length(args) == 3) do
      [numNodes, topology, algorithm] = args
      {totalNodes, _} = Integer.parse(numNodes)

      IO.puts(
        "The #{algorithm} algorithm will run on #{totalNodes} nodes in the #{topology} topology."
      )

      initiatedNodes = Enum.map(1..totalNodes, fn x -> initiateNode(x) end)
      buildTopology(topology, initiatedNodes)
      time1 = System.monotonic_time(:millisecond)
      startAlgorithm(algorithm, initiatedNodes, time1)
      infiniteLoop()
    else
      IO.puts("This input of arguments is not supported")
    end
  end

  def infiniteLoop() do
    infiniteLoop()
  end

  def buildTopology(topology, initiatedNodes) do

    case topology do
      "line" ->
        createLineTopology(initiatedNodes)

      "full" ->
        createFullTopology(initiatedNodes)

      "imp2D" ->
        createImperfectLineTopology(initiatedNodes)

      "rand2D" ->
        createRandom2DTopology(initiatedNodes)

      "3D" ->
        create3DTopology(initiatedNodes)

      "sphere" ->
        createTorusTopology(initiatedNodes)

      _ ->
        IO.puts("This topology is not supported")
    end
  end

  def createLineTopology(nodes) do
    IO.puts("Creating Line Topology")
    numNodes = length(nodes) - 1

    Enum.map(nodes, fn x ->
      index = Enum.find_index(nodes, fn y -> y == x end)

      neighbours =
        case index do
          0 ->
            [Enum.at(nodes, 1)]

          ^numNodes ->
            [Enum.at(nodes, index - 1)]

          nil ->
            "No index found. Major bug"

          _ ->
            [Enum.at(nodes, index - 1)] ++ [Enum.at(nodes, index + 1)]
        end

      GenServer.cast(x, {:updateneighbours, neighbours})
    end)
  end

  def createFullTopology(nodes) do
    IO.puts("Creating Full Network Topology")

    Enum.each(nodes, fn x ->
      neighbours = List.delete(nodes, x)
      GenServer.cast(x, {:updateneighbours, neighbours})
    end)
  end

  def createImperfectLineTopology(nodes) do
    IO.puts("Creating Imperfect Line Topology")
    numNodes = length(nodes) - 1

    Enum.map(nodes, fn x ->
      index = Enum.find_index(nodes, fn y -> y == x end)
      otherNodes = List.delete(nodes, x)

      neighbours =
        case index do
          0 ->
            [Enum.at(nodes, 1)]

          ^numNodes ->
            [Enum.at(nodes, index - 1)]

          nil ->
            "No index found. Major bug"

          _ ->
            [Enum.at(nodes, index - 1), Enum.at(nodes, index + 1)]
        end
      otherNodes = Enum.reduce(neighbours, otherNodes, fn x, acc -> List.delete(acc, x) end)
      randNode = [Enum.random(otherNodes)]
      neighbours = neighbours ++ randNode

      GenServer.cast(x, {:updateneighbours, neighbours})
    end)
  end

  def createRandom2DTopology(nodes) do
    IO.puts("Creating Random2D Topology")

    Enum.map(nodes, fn x ->
      xCoordinate = :rand.uniform()
      yCoordinate = :rand.uniform()
      GenServer.cast(x, {:update, [xCoordinate, yCoordinate]})
      GenServer.call(x, {:getid})
    end)

    Enum.map(nodes, fn x ->
      otherNodes = List.delete(nodes, x)
      [location1x, location1y] = GenServer.call(x, {:getid})

      neighbours =
        Enum.map(otherNodes, fn y ->
          [location2x, location2y] = GenServer.call(y, {:getid})
          dist = :math.pow(location1x - location2x, 2) + :math.pow(location1y - location2y, 2)

          if dist < 0.01 do
            y
          else
            nil
          end
        end)

      neighbours = Enum.filter(neighbours, &(!is_nil(&1)))
      GenServer.cast(x, {:updateneighbours, neighbours})
    end)
  end

  def create3DTopology(nodes) do
    IO.puts("Creating 3D Topology")

    oneDSize = getcuberoot(length(nodes), 0)
    twoDSize = oneDSize * oneDSize

    Enum.map(nodes, fn x ->
      index = Enum.find_index(nodes, fn y -> y == x end)
      zCoordinate = Integer.floor_div(index, twoDSize)
      remainder = rem(index, twoDSize)
      xCoordinate = Integer.floor_div(remainder, oneDSize)
      yCoordinate = rem(remainder, oneDSize)
      GenServer.cast(x, {:update, [xCoordinate, yCoordinate, zCoordinate]})
      GenServer.call(x, {:getid})
    end)

    Enum.map(nodes, fn x ->
      otherNodes = List.delete(nodes, x)
      [location1x, location1y, location1z] = GenServer.call(x, {:getid})

      neighbours =
        Enum.map(otherNodes, fn y ->
          [location2x, location2y, location2z] = GenServer.call(y, {:getid})

          dist =
            abs(location1x - location2x) + abs(location1y - location2y) +
              abs(location1z - location2z)

          if dist == 1 do
            y
          else
            nil
          end
        end)

      neighbours = Enum.filter(neighbours, &(!is_nil(&1)))
      GenServer.cast(x, {:updateneighbours, neighbours})
    end)
  end

  def createTorusTopology(nodes) do
    IO.puts("Creating Torus Topology")

    total = length(nodes)
    oneDSize = trunc(:math.sqrt(total))

    Enum.map(nodes, fn x ->
      index = Enum.find_index(nodes, fn y -> y == x end)
      xCoordinate = Integer.floor_div(index, oneDSize)
      yCoordinate = rem(index, oneDSize)
      GenServer.cast(x, {:update, [xCoordinate, yCoordinate]})
      GenServer.call(x, {:getid})
    end)

    Enum.map(nodes, fn x ->
      otherNodes = List.delete(nodes, x)
      [location1x, location1y] = GenServer.call(x, {:getid})

      neighbours =
        Enum.map(otherNodes, fn y ->
          [location2x, location2y] = GenServer.call(y, {:getid})
          dist = abs(location1x - location2x) + abs(location1y - location2y)

          toReturn =
            if dist == 1 do
              y
            else
              toReturn =
                cond do
                  location1x == 0 and location2y == location1y and location2x == oneDSize - 1 -> y
                  location1x == oneDSize - 1 and location2x == 0 and location2y == location1y -> y
                  true -> nil
                end

              toReturn =
                if toReturn == nil do
                  cond do
                    location1y == 0 and location2x == location1x and location2y == oneDSize - 1 ->
                      y

                    location1y == oneDSize - 1 and location2y == 0 and location2x == location1x ->
                      y

                    true ->
                      nil
                  end
                else
                  toReturn
                end

              toReturn
            end

          toReturn
        end)

      neighbours = Enum.filter(neighbours, &(!is_nil(&1)))
      GenServer.cast(x, {:updateneighbours, neighbours})
    end)
  end

  def getcuberoot(number, counter) do
    if :math.pow(counter, 3) <= number do
      getcuberoot(number, counter + 1)
    else
      counter - 1
    end
  end

  def startAlgorithm(algorithm, allNodes, startTime) do

    case algorithm do
      "gossip" ->
        startGossip(allNodes, startTime)

      "push-sum" ->
        startPushSum(allNodes, startTime)

      _ ->
        IO.puts("No support for this algorithm yet")
    end
  end

  def startGossip(allNodes, startTime) do
    IO.puts "Starting Gossip Algorithm"
    startNode = Enum.random(allNodes)
    table = :ets.new(:table, [:named_table, :public])
    :ets.insert(table, {"count", 0})
    GenServer.cast(startNode, {:increaseCount, 1, length(allNodes),  startTime})
    gossipAllNight(startNode, length(allNodes), startTime)
  end

  def gossipAllNight(node, total, startTime) do
    count = GenServer.call(node, {:getcount})

    if count < 11 do
      neighbours = GenServer.call(node, {:getneighbours})
      randomNeighbour = Enum.random(neighbours)
      Task.start(__MODULE__, :receiveGossip, [randomNeighbour, total, startTime])
      gossipAllNight(node, total, startTime)
    else
      Process.exit(node, :normal)
    end
  end

  def receiveGossip(randomNeighbour, total, startTime) do
    GenServer.cast(randomNeighbour, {:increaseCount, 1, total, startTime})
    gossipAllNight(randomNeighbour, total, startTime)
  end

  def startPushSum(allNodes, startTime) do
    IO.puts("Starting push-sum algorithm")
    table = :ets.new(:table, [:named_table, :public])
    :ets.insert(table, {"count", 0})
    startNode = Enum.random(allNodes)
    receivePushSum(startNode, 0, 0, length(allNodes), startTime)
  end

  def receivePushSum(node, s, w, total_nodes, startTime) do
    {nodeID, counter, neighbours, weight, value} = GenServer.call(node, {:getstate})

    newweight = weight + w
    newvalue = value + s

    change = abs(newweight / newvalue - weight / value)

    if change < :math.pow(10, -10) and counter == 2 do
      count = :ets.update_counter(:table, "count", {2, 1})

      if count == total_nodes do
        time2 = System.monotonic_time(:millisecond)
        totalTime = time2 - startTime
        IO.puts "Time it took to converge is #{totalTime} milliseconds"
                System.halt(1)
      end
    end

    counter =
      if(change < :math.pow(10, -10) && counter < 2) do
        counter + 1
      else
        counter
      end

    counter =
      if(change > :math.pow(10, -10)) do
        0
      else
        counter
      end

    state = {nodeID, counter, neighbours, newweight / 2, newvalue / 2}
    GenServer.cast(node, {:updatestate, state})
    randomNode = Enum.random(neighbours)

    Task.start(__MODULE__, :receivePushSum, [randomNode, newvalue / 2, newweight / 2, total_nodes, startTime])
  end

  def initiateNode(x) do
    {:ok, pid} = GenServer.start_link(__MODULE__, :ok, [])
    GenServer.cast(pid, {:updatesum, x})
    GenServer.cast(pid, {:update, x})
    pid
  end

  def init(:ok) do
    # {s,pscount,adjList,w} , {nodeId,count,adjList,w}
    {:ok, {0, 0, [], 1, 0}}
  end

  def handle_cast({:updateneighbours, new_neighbours}, state) do
    {nodeID, counter, neighbours, weight, s} = state
    state = {nodeID, counter, neighbours ++ new_neighbours, weight, s}
    {:noreply, state}
  end

  def handle_cast({:update, x}, state) do
    {_, counter, neighbours, weight, s} = state
    state = {x, counter, neighbours, weight, s}
    {:noreply, state}
  end

  def handle_cast({:updatesum, s}, state) do
    {x, counter, neighbours, weight, _} = state
    state = {x, counter, neighbours, weight, s}
    {:noreply, state}
  end

  def handle_cast({:increaseCount, value,total, startTime}, state) do
    {nodeID, counter, neighbours, weight, s} = state
    if counter == 0 do
      count = :ets.update_counter(:table, "count", {2,1})

      if(count == total) do
        time2 = System.monotonic_time(:millisecond)
        totalTime = time2 - startTime
        IO.puts "Time it took to converge is #{totalTime} milliseconds"
        System.halt(1)
      end
    end
    state = {nodeID, counter + value, neighbours, weight, s}
    {:noreply, state}
  end

  def handle_cast({:updatestate, newstate}, _state) do
    {:noreply, newstate}
  end

  def handle_call({:getid}, _from, state) do
    {x, _, _, _, _} = state
    {:reply, x, state}
  end

  def handle_call({:getcount}, _from, state) do
    {_, counter, _, _, _} = state

    {:reply, counter, state}
  end

  def handle_call({:getneighbours}, _from, state) do
    {_, _, neighbours, _, _} = state
    {:reply, neighbours, state}
  end

  def handle_call({:getstate}, _from, state) do
    {:reply, state, state}
  end
end

Assignment2.start()
