#!/usr/bin/env ruby2.6

# Copyright latexcleaner.sty, Andrea Alberti (2016)

require 'strscan'

# Adding some useful properties to string class.
class String
  def byteslice(*args)
    self.dup.force_encoding("ASCII-8BIT").slice(*args).force_encoding("UTF-8")
  end
  
  def shortString(len = 30)
    if self.length > 2*len
      str = self[0..len] + " [...] " + self[-len..-1]
    else
      str = self
    end
    return str
  end
end

class LatexCleaner
  BLOCKTOBEREMOVED = "BLOCKTOBEREMOVED"
  
  def initialize(contentTEX,debug=false)
    @debug = debug
    @contentTEX = contentTEX.dup
  end
  
  def contentTEX=(newContentTEX)
    @contentTEX = newContentTEX.dup
  end

  def contentTEXarXiv
    return @contentTEX.gsub(/[[:space:]]*\%*[[:space:]]*\\arXivtrue.*$/,"\n\\arXivtrue").gsub(/[[:space:]]*\\arXivfalse.*$/,"\n\\arXivtrue")
  end

  def contentTEXjournal
    return @contentTEX.gsub(/[[:space:]]*\%*[[:space:]]*\\arXivfalse.*$/,"\n\\arXivfalse").gsub(/[[:space:]]*\\arXivtrue.*$/,"\n\\arXivfalse")
  end
  
  def contentTEX
    return @contentTEX
  end
  
  def figuresRenameMapping
    return @figures_hash
  end
  
  def figuresRenameMapping=(figures_hash)
    @figures_hash = figures_hash
  end
  
  def renameFigures
    # replace figures according to the hash table 'figures_hash'
    counter=1
    @figures_hash.each do |x|
      filename = x.gsub(/\.[^\.]*$/,'')
      
      @contentTEX.gsub!(/\{#{filename}[^\}]*/,"{figure" << counter.to_s << ".pdf")
      counter+=1
    end
  end
  
  def debug
    return @debug
  end
  
  def debug=(debug)
    @debug = debug
  end

  def removeNote(commandName)
    @contentTEX = cleanOrphanLines(recursiveRemoveNote(@contentTEX,commandName,0))
  end
  
  def removeChange
    @contentTEX = cleanOrphanLines(recursiveRemoveChange(@contentTEX,0))
  end

  def removeCommentedOutBlocks
    @contentTEX.gsub!(/^[[:space:]]*\\usepackage.*\{comment\}.*\n/,"\n") # remove comment package for comments
    @contentTEX = cleanOrphanLines(recursiveRemoveCommentedOutBlocks(@contentTEX,0))
  end
  
  def removeCommentPackages
    @contentTEX.gsub!(/^[[:space:]]*\\usepackage.*\{ulem\}.*\n/,"\n") # remove ulem package for comments
    @contentTEX.gsub!(/^[[:space:]]*\\usepackage.*\{editing\}.*\n/,"\n") # remove editing package for comments
    @contentTEX.gsub!(/^[[:space:]]*\\newchange\w*\{.*\n/,"\n") # remove \newchange
    @contentTEX.gsub!(/^[[:space:]]*\\newnote\w*\{.*\n/,"\n") # remove \newnote
    @contentTEX.gsub!(/\\change\w*OnOff/,"\n") # remove \changeOn
    @contentTEX.gsub!(/\\change\w*On/,"\n") # remove \changeOn
    @contentTEX.gsub!(/\\change\w*Off/,"\n") # remove \changeOn
    @contentTEX.gsub!(/\\note\w*On/,"\n") # remove \changeOn
    @contentTEX.gsub!(/\\note\w*Off/,"\n") # remove \changeOn   
  end
  
  def removeComments
    @contentTEX.gsub!(/((?:(?<!\\)\%.+)|(?:^[[:space:]]*\%))\n/,'') # remove comments
  end
  
  def removeMultipleEmptySpaces
    @contentTEX.gsub!(/^[[:blank:]]*$/,'') # replace lines of several spaces with simple space
  end
  
  def removeMultipleEmptyLines
    @contentTEX.gsub!(/(\n|\r|\n\r|\r\n){2,}/, "\n\n") # remove multiple empty lines with a single one
  end
  
  private
  
  def cleanOrphanLines(contentTEX)
    contentTEX.gsub!(/^(.*)#{BLOCKTOBEREMOVED}.*[[:space:]]/) do |x|
      if /^[[:space:]]*(\%.*)?$/ =~ x.gsub(/#{BLOCKTOBEREMOVED}/,'')
        ""
      else
        x.gsub(/#{BLOCKTOBEREMOVED}/,'')
      end
    end
    return contentTEX
  end  
  
  # remove commented blocks
  def recursiveRemoveCommentedOutBlocks(contentTEX,offset)

    ss = StringScanner.new(contentTEX)

    if not ss.scan_until(/(\\begin\{comment\})/m).nil?

      result = ss.pre_match
      detected = ss[1]

      len = findLenCommentedBlock(ss.post_match)
      if len == -1
        err_line = @contentTEX.byteslice(0..ss.pos+offset).lines.count
        STDERR.puts "Encountered error at line #{err_line}: #{detected}"
        exit
      end

      block = ss.peek(len-13)

      if @debug
        dbg_line = @contentTEX.byteslice(0..ss.pos+offset).lines.count
        puts ">>> Detected block commented out [#{dbg_line}]: \n"
        puts block.shortString(200)
      end
      ss.pos = ss.pos + len

      result << BLOCKTOBEREMOVED + recursiveRemoveCommentedOutBlocks(ss.rest,ss.pos)
    else
      result = ss.rest
    end

    return result
  end
  
  
  # remove comments through 'change' command
  def recursiveRemoveChange(contentTEX,offset)

    ss = StringScanner.new(contentTEX)

    if not ss.scan_until(/(\\change[^\{\s]*\{)/m).nil?    

      result = ss.pre_match
      detected = ss[1]

      len = findLenBlock(ss.post_match)
      if len == -1
        err_line = @contentTEX.byteslice(0..ss.pos+offset).lines.count
        STDERR.puts "Encountered error at line #{err_line}: [block1] in #{detected}[block1]\}\{[block2]\} has unbalanced brackets."
        exit
      end
      block1 = ss.peek(len)
      if @debug
        dbg_line = @contentTEX.byteslice(0..ss.pos+offset).lines.count
        puts ">>> Detected \\change block1 [#{dbg_line}]: \n"
        puts block1.shortString
      end
      ss.pos = ss.pos + len + 1

      skiplen = ss.match?(/[[:space:]]*([[:space:]]*\%[^\n]*\n)*\{/m)
      if skiplen.nil?
        err_line = @contentTEX.byteslice(0..ss.pos+offset).lines.count
        STDERR.puts "Encountered error at line #{err_line}: #{detected}[block1]\} is not followed directly by \{[block2]\}"
        exit
      end
      ss.pos = ss.pos + skiplen
    
      len = findLenBlock(ss.post_match)
      if len == -1
        err_line = @contentTEX.byteslice(0..ss.pos+offset).lines.count
        STDERR.puts "Encountered error at line #{err_line}: [block2] in #{detected}[block1]\}\{[block2]\} has unbalanced brackets."
        exit
      end
      block2 = ss.peek(len)
      if @debug
        dbg_line = @contentTEX.byteslice(0..ss.pos+offset).lines.count
        puts ">>> Detected \\change block2 [#{dbg_line}]: \n"
        puts block2.shortString
      end
      ss.pos = ss.pos + len + 1

      result << (recursiveRemoveChange(block1,ss.pos) + BLOCKTOBEREMOVED + recursiveRemoveChange(ss.rest,ss.pos))
    else
      result = ss.rest
    end
    
    return result  
  end
  
  # remove comments through 'change' command
  def recursiveRemoveNote(contentTEX,commandName,offset)

    ss = StringScanner.new(contentTEX)

    if not ss.scan_until(/(\\#{commandName}[^\{\s]*\{)/m).nil?

      result = ss.pre_match
      detected = ss[1]

      len = findLenBlock(ss.post_match)
      if len == -1
        err_line = @contentTEX.byteslice(0..ss.pos+offset).lines.count
        STDERR.puts "Encountered error at line #{err_line}: [block1] in #{detected}[block1]\}\{[block2]\} has unbalanced brackets."
        exit
      end
      block1 = ss.peek(len)
      if @debug
        dbg_line = @contentTEX.byteslice(0..ss.pos+offset).lines.count
        puts ">>> Detected \\note block [#{dbg_line}]: \n"
        puts block1.shortString
      end
      ss.pos = ss.pos + len + 1
    
      result << (BLOCKTOBEREMOVED + recursiveRemoveNote(ss.rest,commandName,ss.pos))
    else
      result = ss.rest
    end
    
    return result  
  end
  
  def findLenCommentedBlock( exp )    
    ss = StringScanner.new(exp)
    stack = 1

    while ss.scan_until(/\\begin\{comment\}|\\end\{comment\}/m) do
      if ss[0].eql? '\begin{comment}'
        stack +=1
      else
        stack -=1
      end
    
      break if stack == 0
    end
  
    if not stack == 0
      idx = -1
    else
      idx = ss.pos
    end

    return idx
  end
  
  def findLenBlock( exp )    
    ss = StringScanner.new(exp)
    stack = 1

    while ss.scan_until(/(?<!\\)\{|(?<!\\)\}/m) do
      case ss[0]
      when '{'
        stack +=1
      when '}'
        stack -=1
      end
    
      break if stack == 0
    end
  
    if not stack == 0
      idx = -1
    else
      idx = ss.pos-1
    end

    return idx
  end
end


# Instead of LatexCleaner, the same through regular expression -- much less flexible
# regex = /\\change[[:space:]]*\{(?<paren1>(?:[^\{\}]*(:?\{[^\{\}]*\})*)+)\}(?:[[:space:]]|\%)*\{(?<paren2>(?:[^\{\}]*(:?\{[^\{\}]*\})*)+)\}/m
# contentTEX.gsub!(regex) { |x|  Regexp.last_match[1][0..-1];}  # remove comments through 'change' command
# regex = /\\note[[:space:]]*\{(?:(?:[^\{\}]*(:?\{[^\{\}]*\})*)+)\}/m
# contentTEX.gsub!(regex,'') # remove notes through 'note' command


