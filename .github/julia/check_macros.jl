using Test

# Function to easily get the extension of a file
function file_extension(file::String)
  pos_dot = findfirst(==('.'), file)
  extension = pos_dot == nothing ? "" : file[pos_dot+1:end]
  return extension
end

function append_macros!(macros::Dict{String,String}, path::String)
  str = read(path, String)
  lines = split(str, '\n')
  for line in lines
    if startswith(line, "#define")
      tab = split(line, " ")
      macros[tab[2]]  = tab[3]
    end
  end
  return macros
end

global n = 0
macros = Dict{String,String}()
append_macros!(macros, joinpath(@__DIR__, "..", "..", "include", "galahad_modules.h"))
append_macros!(macros, joinpath(@__DIR__, "..", "..", "include", "galahad_blas.h"))
append_macros!(macros, joinpath(@__DIR__, "..", "..", "include", "galahad_lapack.h"))

# Check the number of characters
for (root, dirs, files) in walkdir(joinpath(@__DIR__, "..", "..", "src"))
  for file in files
    path = joinpath(root, file)
    code = read(path, String)
    lines = split(code, '\n')
    for (i, line) in enumerate(lines)
      if (file_extension(file) == "f") && (length(line) > 72)
        println("Line $i in the file $file has more than 72 characters.")
        global n = n+1
      end
      if (file_extension(file) ∈ ["f90", "F90"]) && (length(line) > 80)
        println("Line $i in the file $file has more than 80 characters.")
        global n = n+1
      end
      for symbol in keys(macros)
        if occursin(symbol, line) && (file_extension(file) == "f")
          line2 = replace(line, symbol => macros[symbol])
          if length(line2) > 72
            println("Line $i in the file $file has more than 72 characters if $symbol is replaced by $(macros[symbol]).")
            global n = n+1
          end
        end
        if occursin(symbol, line) && (file_extension(file) ∈ ["f90", "F90"])
          line2 = replace(line, symbol => macros[symbol])
          if length(line2) > 80
            println("Line $i in the file $file has more than 80 characters if $symbol is replaced by $(macros[symbol]).")
            global n = n+1
          end
        end
      end
    end
  end
end

@test n == 0