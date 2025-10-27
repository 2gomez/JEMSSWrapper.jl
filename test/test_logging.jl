@testset "Logging Tests" begin
    
    # =========================================================================
    # Mock Encoder
    # =========================================================================
    
    struct MockEncoder <: JEMSSWrapper.AbstractEncoder end
    
    function JEMSSWrapper.encode_state(::MockEncoder, sim, amb_idx)
        return Float64[1.0, 2.0, Float64(amb_idx)]
    end
    
    # =========================================================================
    # Basic Structures
    # =========================================================================
    
    @testset "MoveUpDecision" begin
        decision = JEMSSWrapper.MoveUpDecision(5, 2, 7, 123.45)
        
        @test decision.ambulance_index == 5
        @test decision.from_station == 2
        @test decision.to_station == 7
        @test decision.timestamp == 123.45
    end
    
    @testset "MoveUpLogEntry" begin
        decisions = [JEMSSWrapper.MoveUpDecision(1, 1, 2, 100.0)]
        
        entry = JEMSSWrapper.MoveUpLogEntry(
            100.0,
            1,
            [1.0, 2.0, 3.0],
            [0.1, 0.7, 0.2],
            decisions,
            "TestStrategy"
        )
        
        @test entry.timestamp == 100.0
        @test entry.triggering_ambulance == 1
        @test length(entry.encoded_state) == 3
        @test length(entry.decisions) == 1
        @test entry.strategy_type == "TestStrategy"
    end
    
    # =========================================================================
    # MoveUpLogger Operations
    # =========================================================================
    
    @testset "MoveUpLogger - Basic Operations" begin
        encoder = MockEncoder()
        logger = JEMSSWrapper.MoveUpLogger(encoder)
        
        # Add entries
        entry1 = JEMSSWrapper.MoveUpLogEntry(
            100.0, 1, [1.0, 2.0], [0.5, 0.5],
            [JEMSSWrapper.MoveUpDecision(1, 1, 2, 100.0)],
            "Strategy1"
        )
        
        entry2 = JEMSSWrapper.MoveUpLogEntry(
            200.0, 2, [3.0, 4.0], [0.3, 0.7],
            [JEMSSWrapper.MoveUpDecision(2, 3, 4, 200.0)],
            "Strategy2"
        )
        
        JEMSSWrapper.add_entry!(logger, entry1)
        JEMSSWrapper.add_entry!(logger, entry2)
        
        entries = JEMSSWrapper.get_entries(logger)
        @test length(entries) == 2
        @test entries[1].timestamp < entries[2].timestamp
        
        # Clear
        JEMSSWrapper.clear_log!(logger)
    end
    
    # =========================================================================
    # DataFrame Conversion
    # =========================================================================
    
    @testset "to_dataframe - Basic" begin
        encoder = MockEncoder()
        logger = JEMSSWrapper.MoveUpLogger(encoder)
        
        # Empty logger
        @test_logs (:warn,) begin
            df = JEMSSWrapper.to_dataframe(logger)
            @test isempty(df)
        end
        
        # With data
        for i in 1:3
            entry = JEMSSWrapper.MoveUpLogEntry(
                Float64(i * 100),
                i,
                [Float64(i), Float64(i+1)],
                [0.5, 0.5],
                [JEMSSWrapper.MoveUpDecision(i, 1, 2, Float64(i * 100))],
                "Strategy"
            )
            JEMSSWrapper.add_entry!(logger, entry)
        end
        
        df = JEMSSWrapper.to_dataframe(logger)
        
        @test nrow(df) == 3
        @test df.timestamp == [100.0, 200.0, 300.0]
        @test "state_1" in names(df)
        @test "output_1" in names(df)
    end
    
    @testset "to_dataframe - Non-Vector Output" begin
        encoder = MockEncoder()
        logger = JEMSSWrapper.MoveUpLogger(encoder)
        
        entry = JEMSSWrapper.MoveUpLogEntry(
            100.0, 1, [1.0, 2.0], "result",
            [JEMSSWrapper.MoveUpDecision(1, 1, 2, 100.0)],
            "Strategy"
        )
        
        JEMSSWrapper.add_entry!(logger, entry)
        df = JEMSSWrapper.to_dataframe(logger)
        
        @test "output" in names(df)  # Single output column
        @test df.output[1] == "result"
    end
    
    # =========================================================================
    # CSV Persistence
    # =========================================================================
    
    @testset "save_dataframe" begin
        encoder = MockEncoder()
        logger = JEMSSWrapper.MoveUpLogger(encoder)
        
        entry = JEMSSWrapper.MoveUpLogEntry(
            100.0, 1, [1.0], [0.5],
            [JEMSSWrapper.MoveUpDecision(1, 1, 2, 100.0)],
            "Strategy"
        )
        JEMSSWrapper.add_entry!(logger, entry)
        
        temp_file = tempname()
        
        @test_logs (:info,) JEMSSWrapper.save_dataframe(logger, temp_file)
        
        csv_file = temp_file * ".csv"
        @test isfile(csv_file)
        
        # Read back
        df = CSV.read(csv_file, DataFrame)
        @test nrow(df) == 1
        @test df.timestamp[1] == 100.0
        
        # Cleanup
        rm(csv_file)
    end
    
end  # @testset "Logging Tests"