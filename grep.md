# grep "Jane Williams"  names.txt
                                                ------------>      "Jane Williams" 
                                                ------------>      "Jane Williamson"


# grep -w "Jane Williams"  names.txt            ------------>      -w = whole world
                                                ------------>      "Jane Williams" 
                                
# grep -win "Jane Williams"  names.txt          ------------>      -w = whole world , i = case insensitive , n = line number of match
                                                ------------>      51: jane williams
                                                ------------>      90: Jane Williams

# grep -win -B 4 "Jane Williams"  names.txt     ------------>      -w = whole world , i = case insensitive , n = line number of match , B 4 = get 4 line after the match
                                                ------------>      47: abcd
                                                ------------>      48: efgh
                                                ------------>      49: ijkl
                                                ------------>      50: mnop
                                                ------------>      51: jane williams       
                                                
                                                ------------>      96: qrst
                                                ------------>      97: uvwx
                                                ------------>      98: yz
                                                ------------>      99: abcd
                                                ------------>      90: Jane Williams 
  
# grep -win -B 4 "Jane Williams"  names.txt     ------------>      -w = whole world , i = case insensitive , n = line number of match , A 4 = get 4 line after the match
                                                ------------>      47: jane williams 
                                                ------------>      48: efgh
                                                ------------>      49: ijkl
                                                ------------>      50: mnop
                                                ------------>      51: qrsr      
                                                
                                                ------------>      96: Jane Williams
                                                ------------>      97: uvwx
                                                ------------>      98: yz
                                                ------------>      99: abcd
                                                ------------>      90: efgh                                                                                     

# grep -win -C 2 "Jane Williams"  names.txt     ------------>      -w = whole world , i = case insensitive , n = line number of match , C 2 = get 2 line bef/af the match
                                                ------------>      47: abcd 
                                                ------------>      48: efgh
                                                ------------>      49: jane williams
                                                ------------>      50: mnop
                                                ------------>      51: qrsr      
                                                
                                                ------------>      96: qrst
                                                ------------>      97: uvwx
                                                ------------>      98: Jane Williams
                                                ------------>      99: abcd
                                                ------------>      90: efgh                                                                                     

# grep -win  "Jane Williams"  ./*               ------------>      ./* = search every file in the directory not in subdirectory

# grep -win  "Jane Williams"  ./*.txt           ------------>      ./*.txt = search every text file in the directory not in subdirectory

# grep -winr "Jane Williams"  ./                ------------>      ./ & r = search every file in the directory and  recursively in subdirectory

# grep -wirl "Jane Williams"  ./                ------------>      ./ & r & l = listing any file in the directory and  recursively in subdirectory containing the match

# grep -wirc "Jane Williams"  ./                ------------>      ./ & r & c = list number of times any file in the directory and in subdirectory containing the match

# history | grep "git commit" | grep "dotfile"  ------------>      | = result of one grep sent as input to other grep
                                                ------------>      git commit -m "Updated dotfiles"
                                                ------------>      git commit -m "Updated .bash_profile in dotfiles"
                                                ------------>      history | grep "git commit" | grep "dotfile" 

# grep -P "\{3}-\{3}-\{4}" names.txt            ------------>                                                         

# grep -P "...-...-...." names.txt              ------------>      980-300-1980