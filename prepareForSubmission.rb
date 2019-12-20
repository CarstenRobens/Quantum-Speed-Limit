#!/usr/bin/env ruby2.6

### CUSTOMIZATION VARIABLES ###

texSRC="QSLpaper.tex"
destName="QSLpaper_clean.tex"
                
extra_files = ["QSLpaper.bbl"]

### START PROGRAM ###

require_relative 'latexCleaner'
require 'fileutils'

at_exit do  
  if $! # If the program exits due to an exception
    STDOUT.flush
    STDERR.puts "Errors have been encountered!"
  end
end

texFile = File.open(texSRC,'r');
contentTEX = texFile.read;
texFile.close;

latexCleaner = LatexCleaner.new(contentTEX)

latexCleaner.removeChange
# latexCleaner.removeNote("note")
# latexCleaner.removeNote("STOP")
# latexCleaner.removeComments
# latexCleaner.removeCommentPackages
# latexCleaner.removeMultipleEmptySpaces

# latexCleaner.figuresRenameMapping = { "figures/4atoms.pdf"=>"figure1.pdf",
#                                       "figures/Synthesizer.pdf"=>"figure2.pdf",
#                                       "figures/SortingAlgorithm.pdf"=>"figure3.pdf"}
# latexCleaner.renameFigures

contentTEX = latexCleaner.contentTEX

# write the tex manuscript file
texFile = File.open(destName,'w');
numBytes = texFile.write(contentTEX);
texFile.close;

puts("Written " + numBytes.to_s + " bytes to " + Dir.pwd + "/" + destName)
