using JEMSS: jemssDir

println(" Building JEMSSWrapper...")

# Unzip JEMSS data
jemss_data_dir = joinpath(jemssDir, "data")
unzip_script_path = joinpath(jemss_data_dir, "unzip_data.jl")

if !isfile(unzip_script_path)
    @warn "Unzip script not found at: $unzip_script_path"
    @warn "Skipping data decompression. JEMSS data might already be decompressed."
else
    cd(jemss_data_dir) do
        include(unzip_script_path)
    end
    println("   JEMSS data decompressed")
end

# Create symbolic links
wrapper_dir = dirname(@__DIR__)
scenarios_dir = joinpath(wrapper_dir, "examples", "scenarios")
mkpath(scenarios_dir)

cities = ["auckland", "edmonton", "manhattan", "utrecht"]
jemss_cities_dir = joinpath(jemss_data_dir, "cities")

if !isdir(jemss_cities_dir)
    error("JEMSS cities directory not found at: $jemss_cities_dir\n" *
          "Please ensure JEMSS is properly installed.")
end

for city in cities
    # Source path
    src_models = joinpath(jemss_cities_dir, city, "models", "1")
    
    if !isdir(src_models)
        @warn "Source directory not found for $city: $src_models"
        continue
    end
    
    # Destination paths
    dst = joinpath(scenarios_dir, city)
    dst_models = joinpath(dst, "models")
    
    # Create city directory if needed
    mkpath(dst)
    
    # Handle existing destination
    if islink(dst_models)
        # Check if link points to correct location
        if readlink(dst_models) == src_models
            println("   $city linked")
            continue
        else
            # Remove incorrect link
            rm(dst_models)
        end
    elseif isdir(dst_models)
        # Remove existing directory (shouldn't happen in normal use)
        rm(dst_models, recursive=true)
    elseif isfile(dst_models)
        # Remove file if it exists (shouldn't happen)
        rm(dst_models)
    end
    
    # Create symbolic link
    try
        symlink(src_models, dst_models)
        println("   $city linked")
    catch e
        @error "Failed to create symbolic link for $city" exception=(e, catch_backtrace())
        
        if Sys.iswindows()
            @warn """
            On Windows, symbolic links require either:
            1. Developer Mode enabled (Windows 10+)
            2. Running Julia as Administrator
            3. Using WSL
            
            You can still use JEMSSWrapper by manually copying the directories:
            From: $src_models
            To:   $dst_models
            """
        end
    end
end

println(" Build complete!")