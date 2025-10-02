using JEMSS: jemssDir

println(" Building JEMSSWrapper...")

# Unzip JEMSS data
jemss_data_dir = joinpath(jemssDir, "data")
unzip_script_path = joinpath(jemss_data_dir, "unzip_data.jl")

cd(jemss_data_dir) do
    include(unzip_script_path)
end
println("   JEMSS data decompressed")

# Create simbolic links
wrapper_dir = dirname(@__DIR__)
scenarios_dir = joinpath(wrapper_dir, "examples", "scenarios")
mkpath(scenarios_dir)

cities = ["auckland", "edmonton", "manhattan", "utrecht"]
jemss_cities_dir = joinpath(jemss_data_dir, "cities")

for city in cities
    # Source paths
    src_models = joinpath(jemss_cities_dir, city, "models", "1")
    
    # Destination paths
    dst = joinpath(scenarios_dir, city)
    dst_models = joinpath(dst, "models")
    
    # Create simbolic links if not exist
    islink(dst_models) || isdir(dst_models) || symlink(src_models, dst_models)
    
    println("   $city linked")
end

println(" Build complete!")