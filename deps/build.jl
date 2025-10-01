using Pkg
using JEMSS: jemssDir

jemss_data_dir = joinpath(jemssDir, "data")
unzip_script_path = joinpath(jemss_data_dir, "unzip_data.jl")
include(unzip_script_path)

wrapper_dir = dirname(@__DIR__)
scenarios_dir = joinpath(wrapper_dir, "example", "scenarios")
cities = ["auckland", "edmonton", "manhattan", "utrecht"]
jemss_cities_dir = joinpath(jemss_data_dir, "cities")

for city in cities
    src = joinpath(jemss_cities_dir, city)
    dst = joinpath(scenarios_dir, city)

    src_data = joinpath(src, "data")
    src_models = joinpath(src, "models")

    dst_data = joinpath(dst, "data")
    dst_models = jointpath(src, "models")

    symlink(src_data, dst_data)
    symlink(src_models, dst_models)
end
