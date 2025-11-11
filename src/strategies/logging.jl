"""
    MoveUpLogEntry

Complete log entry for a move-up decision event.

# Fields
- `encoded_state::Vector{Float32}`: Encoded simulation state using the logger's encoder
- `strategy_output::Any`: Raw output from the strategy (e.g., neural network output vector, optimization result)
- `strategy_type::String`: Name of the strategy that made the decision
"""
struct MoveUpLogEntry
    encoded_state::Vector{Float32}
    strategy_output::Any
    strategy_type::String
end

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

"""
    create_log_entry(strategy::AbstractMoveUpStrategy, 
                    encoded_state::Vector{Float32},
                    strategy_output::Vector{Float32})
Helper function to create a log entry from move-up decision data.

This function is called by strategies that have a logger to create standardized log entries.
Strategies can override this method if they need custom logging behavior.

# Arguments
- `strategy::AbstractMoveUpStrategy`: The strategy instance
- `encoded_state::Vector{Float32}`: Encoded state vector (typically from logger's encoder)
- `strategy_output::Any`: Raw output from the strategy (e.g., NN output, optimization result)

# Returns
- `MoveUpLogEntry`: Complete log entry ready to be added to a logger
"""
function create_log_entry(
    strategy::AbstractMoveUpStrategy,
    encoded_state::Vector{Float32},
    strategy_output::Vector{Float32},
)
    # Create and return log entry
    return MoveUpLogEntry(
        encoded_state,
        strategy_output,
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

Get all logged entries in chronological order. 
"""
get_entries(logger::MoveUpLogger) = logger.entries

"""
    clear_log!(logger::MoveUpLogger)

Clear all logged entries.
"""
function clear_log!(logger::MoveUpLogger)
    empty!(logger.entries)
    return nothing
end

# ============================================================================
# DataFrame Conversion
# ============================================================================
"""
    to_dataframe(logger::MoveUpLogger) -> DataFrame

Convert logged entries to a DataFrame with one row per log entry.

# Column structure
- `strategy_type`: Name of the strategy used
- `state_1, state_2, ..., state_n`: Encoded state dimensions, according to encoder.features_names
- `output_1, output_2, ...`: Strategy output dimensions

# Notes
- State column names come from `encoder.features_names`
- Output columns are numbered generically (output_1, output_2, etc.)
- Returns an empty DataFrame if no entries are logged
- All entries are assumed to have the same state and output dimensions
"""
function to_dataframe(logger::MoveUpLogger)
    entries = get_entries(logger)
    
    if isempty(entries)
        @warn "No entries to convert to DataFrame"
        return DataFrame()
    end
    
    # Get feature names from encoder
    state_feature_names = logger.encoder.features_names
    
    # Determine dimensions from first entry
    first_entry = entries[1]
    state_dim = length(first_entry.encoded_state)
    output_dim = length(first_entry.strategy_output)
    
    # Validate that feature names match state dimension
    if length(state_feature_names) != state_dim
        @warn "Feature names count ($(length(state_feature_names))) doesn't match state dimension ($state_dim). Using generic names."
        state_feature_names = ["state_$j" for j in 1:state_dim]
    end
    
    # Pre-allocate vectors for each column
    n = length(entries)
    strategy_types = Vector{String}(undef, n)
    
    # State columns (as Matrix for efficiency)
    state_data = Matrix{Float32}(undef, n, state_dim)
    
    # Output columns (type depends on what strategies return, but typically Float64)
    # We'll infer the type from the first entry
    output_type = eltype(first_entry.strategy_output)
    output_data = Matrix{output_type}(undef, n, output_dim)
    
    # Fill data
    for (i, entry) in enumerate(entries)
        # State (already Float32)
        state_data[i, :] = entry.encoded_state
        
        # Output (convert to appropriate type)
        output_data[i, :] = entry.strategy_output
    end
    
    # Build DataFrame starting with metadata
    df = DataFrame()
    
    # Add state columns with feature names from encoder
    for (j, feature_name) in enumerate(state_feature_names)
        df[!, Symbol(feature_name)] = state_data[:, j]
    end
    
    # Add output columns with generic names
    for j in 1:output_dim
        df[!, Symbol("output_$j")] = output_data[:, j]
    end

    return df 
end