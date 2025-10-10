"""
Data structures for logging move-up decisions.
"""

# ============================================================================
# Core Data Structures
# ============================================================================

"""
    MoveUpDecision

Represents a single ambulance relocation decision.

# Fields
- `ambulance_index::Int`: Index of the ambulance that was moved
- `from_station::Int`: Origin station index
- `to_station::Int`: Target station index
- `timestamp::Float64`: Simulation time when decision was made
"""
struct MoveUpDecision
    ambulance_index::Int
    from_station::Int
    to_station::Int
    timestamp::Float64
end

"""
    MoveUpLogEntry

Complete log entry for a move-up decision event.

# Fields
- `timestamp::Float64`: Simulation time when move-up was triggered
- `triggering_ambulance::Int`: Index of ambulance that triggered the move-up consideration
- `encoded_state::Vector{Float64}`: Encoded simulation state using the logger's encoder
- `strategy_output::Any`: Raw output from the strategy (e.g., neural network output vector, optimization result)
- `decisions::Vector{MoveUpDecision}`: List of relocation decisions made (can be multiple ambulances)
- `strategy_type::String`: Name of the strategy that made the decision
"""
struct MoveUpLogEntry
    timestamp::Float64
    triggering_ambulance::Int
    encoded_state::Vector{Float64}
    strategy_output::Any
    decisions::Vector{MoveUpDecision}
    strategy_type::String
end

# ============================================================================
# Logger
# ============================================================================

"""
    MoveUpLogger

Logger for recording move-up decisions during simulation.

The logger uses an encoder to create uniform state representations across different strategies,
enabling comparison and analysis of different approaches.

# Fields
- `encoder::AbstractEncoder`: Encoder for creating uniform state representations
- `entries::Vector{MoveUpLogEntry}`: Logged entries (chronologically ordered)

# Notes
- The logger is passed as an optional field to move-up strategies
- Each strategy is responsible for calling the logger within its `decide_moveup` method
- The same logger can be reused across multiple simulations (clear between runs if needed)
"""
mutable struct MoveUpLogger
    encoder::AbstractEncoder
    entries::Vector{MoveUpLogEntry}
    
    function MoveUpLogger(encoder::AbstractEncoder)
        new(encoder, MoveUpLogEntry[])
    end
end

# ============================================================================
# Logger Operations
# ============================================================================

"""
    create_log_entry(strategy::AbstractMoveUpStrategy, sim::JEMSS.Simulation,
                    triggering_ambulance::JEMSS.Ambulance, encoded_state::Vector{Float64},
                    strategy_output::Any, movable_ambulances::Vector{JEMSS.Ambulance},
                    target_stations::Vector{JEMSS.Station}; metadata::Dict{Symbol,Any}=Dict{Symbol,Any}())

Helper function to create a log entry from move-up decision data.

This function is called by strategies that have a logger to create standardized log entries.
Strategies can override this method if they need custom logging behavior.

# Arguments
- `strategy::AbstractMoveUpStrategy`: The strategy instance
- `sim::JEMSS.Simulation`: Current simulation state
- `triggering_ambulance::JEMSS.Ambulance`: Ambulance that triggered the move-up consideration
- `encoded_state::Vector{Float64}`: Encoded state vector (typically from logger's encoder)
- `strategy_output::Any`: Raw output from the strategy (e.g., NN output, optimization result)
- `movable_ambulances::Vector{JEMSS.Ambulance}`: Ambulances that were moved
- `target_stations::Vector{JEMSS.Station}`: Target stations for the ambulances (parallel to movable_ambulances)

# Returns
- `MoveUpLogEntry`: Complete log entry ready to be added to a logger
"""
function create_log_entry(
    strategy::AbstractMoveUpStrategy,
    sim::JEMSS.Simulation,
    triggering_ambulance::JEMSS.Ambulance,
    encoded_state::Vector{Float64},
    strategy_output::Any,
    movable_ambulances::Vector{JEMSS.Ambulance},
    target_stations::Vector{JEMSS.Station}
)
    # Create decision records for each ambulance-station pair
    decisions = [
        MoveUpDecision(
            amb.index,
            amb.stationIndex,
            station.index,
            sim.time
        )
        for (amb, station) in zip(movable_ambulances, target_stations)
    ]
    
    # Create and return log entry
    return MoveUpLogEntry(
        sim.time,
        triggering_ambulance.index,
        encoded_state,
        strategy_output,
        decisions,
        string(typeof(strategy))
    )
end

"""
    add_entry!(logger::MoveUpLogger, entry::MoveUpLogEntry)

Add a log entry to the logger.

This function is typically called from within a strategy's `decide_moveup` method.
"""
function add_entry!(logger::MoveUpLogger, entry::MoveUpLogEntry)
    push!(logger.entries, entry)
    return nothing
end

"""
    get_entries(logger::MoveUpLogger) -> Vector{MoveUpLogEntry}

Get all logged entries.

Returns entries in chronological order (order they were added).
"""
get_entries(logger::MoveUpLogger) = logger.entries

"""
    clear_log!(logger::MoveUpLogger)

Clear all logged entries.

Useful when reusing the same logger across multiple simulation runs.
"""
function clear_log!(logger::MoveUpLogger)
    empty!(logger.entries)
    return nothing
end

"""
    num_entries(logger::MoveUpLogger) -> Int

Get the number of logged entries.
"""
num_entries(logger::MoveUpLogger) = length(logger.entries)

# ============================================================================
# DataFrame Conversion
# ============================================================================

"""
    to_dataframe(logger::MoveUpLogger) -> DataFrame

Convert logged entries to a DataFrame with one row per log entry.

# Column structure
- `timestamp`: Simulation time when move-up was triggered
- `triggering_ambulance`: Index of ambulance that triggered the move-up
- `strategy_type`: Name of the strategy used
- `num_decisions`: Number of ambulances relocated in this move-up event
- `state_1, state_2, ..., state_n`: Encoded state dimensions
- `output_1, output_2, ..., output_m`: Strategy output dimensions (if output is a vector)

# Notes
- If an entry has multiple decisions, only the count is recorded (num_decisions)
- If strategy_output is not a vector, it is stored as a single column `output`
- Returns an empty DataFrame if no entries are logged
"""
function to_dataframe(logger::MoveUpLogger)
    entries = get_entries(logger)
    
    if isempty(entries)
        @warn "No entries to convert to DataFrame"
        return DataFrame()
    end
    
    # Determine dimensions
    state_dim = length(entries[1].encoded_state)
    
    # Check if outputs are vectors and get dimension
    first_output = entries[1].strategy_output
    output_is_vector = first_output isa AbstractVector
    output_dim = output_is_vector ? length(first_output) : 1
    
    # Pre-allocate vectors for each column
    n = length(entries)
    timestamps = Vector{Float64}(undef, n)
    triggering_ambulances = Vector{Int}(undef, n)
    strategy_types = Vector{String}(undef, n)
    num_decisions = Vector{Int}(undef, n)
    
    # State columns
    state_data = Matrix{Float64}(undef, n, state_dim)
    
    # Output columns
    if output_is_vector
        output_data = Matrix{Float64}(undef, n, output_dim)
    else
        output_data = Vector{Any}(undef, n)
    end
    
    # Fill data
    for (i, entry) in enumerate(entries)
        timestamps[i] = entry.timestamp
        triggering_ambulances[i] = entry.triggering_ambulance
        strategy_types[i] = entry.strategy_type
        num_decisions[i] = length(entry.decisions)
        
        # State
        state_data[i, :] = entry.encoded_state
        
        # Output
        if output_is_vector
            output_data[i, :] = entry.strategy_output
        else
            output_data[i] = entry.strategy_output
        end
    end
    
    # Build DataFrame
    df = DataFrame(
        timestamp = timestamps,
        triggering_ambulance = triggering_ambulances,
        strategy_type = strategy_types,
        num_decisions = num_decisions
    )
    
    # Add state columns
    for j in 1:state_dim
        df[!, Symbol("state_$j")] = state_data[:, j]
    end
    
    # Add output columns
    if output_is_vector
        for j in 1:output_dim
            df[!, Symbol("output_$j")] = output_data[:, j]
        end
    else
        df[!, :output] = output_data
    end
    
    return df
end

"""
    save_dataframe(logger::MoveUpLogger, filepath::String)

Convert logger entries to DataFrame and save as CSV.

# Arguments
- `filepath`: Path where the CSV file will be saved

# Notes
- Automatically appends .csv extension if not present
- Overwrites existing files
"""
function save_dataframe(logger::MoveUpLogger, filepath::String)
    # Ensure .csv extension
    if !endswith(filepath, ".csv")
        filepath = filepath * ".csv"
    end
    
    df = to_dataframe(logger)
    
    if isempty(df)
        @warn "No data to save"
        return nothing
    end
    
    CSV.write(filepath, df)
    @info "DataFrame saved" filepath=filepath rows=nrow(df) columns=ncol(df)
    
    return nothing
end