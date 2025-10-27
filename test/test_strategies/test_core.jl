# =========================================================================
# Mock Implementations
# =========================================================================

struct SimpleEncoder <: JEMSSWrapper.AbstractEncoder end

function JEMSSWrapper.encode_state(::SimpleEncoder, sim::JEMSS.Simulation, amb_idx::Int)
    return Float64[length(sim.ambulances), sim.numStations, Float64(amb_idx), sim.time]
end

struct SimpleNetwork <: JEMSSWrapper.AbstractNeuralNetwork
    output_dim::Int
    weights::Vector{Float64}
end

SimpleNetwork(input_dim::Int, output_dim::Int) = SimpleNetwork(output_dim, randn(output_dim))

function JEMSSWrapper.forward(net::SimpleNetwork, input::Vector{Float64})
    # Simple softmax output
    raw = net.weights .+ sum(input)
    exp_vals = exp.(raw .- maximum(raw))
    return exp_vals ./ sum(exp_vals)
end

get_parameters(net::SimpleNetwork) = copy(net.weights)

function set_parameters!(net::SimpleNetwork, params::Vector{Float64})
    net.weights .= params
    return nothing
end

# =========================================================================
# Helper: Load Test Scenario
# =========================================================================

function load_test_scenario()
    return JEMSSWrapper.load_scenario_from_config("auckland", "base.toml")
end

@testset "Strategies Core Tests" begin
    # =========================================================================
    # Abstract Type Tests
    # =========================================================================
    
    @testset "AbstractEncoder Interface" begin
        encoder = SimpleEncoder()
        @test encoder isa JEMSSWrapper.AbstractEncoder
        
        scenario = load_test_scenario()
        if !isnothing(scenario)
            sim = JEMSSWrapper.create_simulation_instance(scenario)
            state = JEMSSWrapper.encode_state(encoder, sim, 1)
            
            @test state isa Vector{Float64}
            @test length(state) == 4
        end
        
        # Unimplemented encoder
        struct BadEncoder <: JEMSSWrapper.AbstractEncoder end
        @test_throws Exception JEMSSWrapper.encode_state(BadEncoder(), nothing, 1)
    end
    
    @testset "AbstractNeuralNetwork Interface" begin
        network = SimpleNetwork(4, 3)
        @test network isa JEMSSWrapper.AbstractNeuralNetwork
        
        # Forward pass
        output = JEMSSWrapper.forward(network, [1.0, 2.0, 3.0, 4.0])
        @test length(output) == 3
        @test sum(output) ≈ 1.0
        
        # Parameters
        params = JEMSSWrapper.get_parameters(network)
        @test length(params) == 3
        
        new_params = randn(3)
        JEMSSWrapper.set_parameters!(network, new_params)
        @test network.weights == new_params
        
        # Unimplemented network
        struct BadNetwork <: JEMSSWrapper.AbstractNeuralNetwork end
        @test_throws ErrorException JEMSSWrapper.forward(BadNetwork(), [1.0])
    end

    # =========================================================================
    # Null Strategy 
    # =========================================================================
    
    @testset "NullStrategy" begin
        strategy = JEMSSWrapper.NullStrategy()

        @test strategy isa JEMSSWrapper.AbstractMoveUpStrategy

        scenario = load_test_scenario() 
        if !isnothing(scenario)
            sim = JEMSSWrapper.create_simulation_instance(scenario)
            @test JEMSSWrapper.should_trigger_on_dispatch(strategy, sim) == false
            @test JEMSSWrapper.should_trigger_on_free(strategy, sim) == false
        else
            @test_skip "Scenario not available"
        end

        scenario = load_test_scenario()
        if !isnothing(scenario)
            sim = JEMSSWrapper.create_simulation_instance(scenario)
            movable, targets = JEMSSWrapper.decide_moveup(strategy, sim, sim.ambulances[1])
            
            @test isempty(movable)
            @test isempty(targets)
        end
    end

    @testset "NullStrategy - With Logger" begin
        encoder = SimpleEncoder()
        logger = JEMSSWrapper.MoveUpLogger(encoder)
        strategy = JEMSSWrapper.NullStrategy(logger=logger)

        @test !isnothing(strategy.logger)

        scenario = load_test_scenario()
        if !isnothing(scenario)
            sim = JEMSSWrapper.create_simulation_instance(scenario)
            JEMSSWrapper.decide_moveup(strategy, sim, sim.ambulances[1])
            
            @test JEMSSWrapper.num_entries(logger) == 1
            @test JEMSSWrapper.get_entries(logger)[1].strategy_type == "NullStrategy"
        end
    end
 
    # =========================================================================
    # Utility Functions
    # =========================================================================
    
    @testset "validate_moveup_decision" begin
        scenario = load_test_scenario()
        if !isnothing(scenario)
            sim = JEMSSWrapper.create_simulation_instance(scenario)
            
            # Length mismatch
            movable = [sim.ambulances[1]]
            targets = [sim.stations[1], sim.stations[2]]
            
            @test_logs (:warn,) begin
                result = JEMSSWrapper.validate_moveup_decision(movable, targets)
                @test result == false
            end
        end
    end
    
    @testset "create_log_entry" begin
        encoder = SimpleEncoder()
        scenario = load_test_scenario()
        
        if !isnothing(scenario)
            sim = JEMSSWrapper.create_simulation_instance(scenario)
            strategy = JEMSSWrapper.NullStrategy()
            
            entry = JEMSSWrapper.create_log_entry(
                strategy, sim, sim.ambulances[1],
                [1.0, 2.0], [0.5, 0.5],
                [sim.ambulances[1]], [sim.stations[2]]
            )
            
            @test entry isa JEMSSWrapper.MoveUpLogEntry
            @test entry.timestamp == sim.time
            @test length(entry.decisions) == 1
        end
    end
    
end  # @testset "Strategies Tests"