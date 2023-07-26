# Docs 
aka *documentation*

This isn't actual documentation, just a collection of the documents I have made while working on the C-Editor.
Maybe it can be of interest to some - I mostly put it here to document (pun intended) how different forms of
paper-sketches can help in building code.

## [c-editor sketches.pdf](c-editor%20sketches.pdf)

A collection of loose papers scattered around my desk while working. I have often jotted down notes on any available surface, so these aren't necessarily in any particular order.

### page 1
Contains my first go at "documenting" the entire workflow in the upper left corner, and then I immediately stopped that.

After that there are some experiments on what happens with the flags in the 6502 with different comparisons - I clearly needed a refresher.

Then we have some loose notes, I have no idea, and some drawings on how to handle copying of overlapping memory-areas, used for the mem_copy function to determine if it should use forwards or backwards copying! Very useful.

Something to do with breaking lines ...

And some calculations to check if the previous copy direction decision is behaving as should.

### page 2
Is for my improved mem_copy, where I copy a full block (256 bytes) before calculating the next address - in the first version I did the calculation for every byte, took a lot of unnecessary cycles.

After that it looks like some offset calculations - not sure - again the paper was just lying there.

### page 3
Is my only page of actual design documentation!

After having too many problems with insert and delete, I decided to re-design the entire code, and drew these diagrams of what should happen in every case of using delete, newline (return) or insert.

They helped a lot - especially since I saw that every newline was the same: there would always be characters before and after a newline, but sometimes the number of characters would be zero. The result would still be creating a new line, and copying those characters though, erasing the remainder with spaces!

I really recommend doing designs like this - it is a huge part of **"understanding the solution"**.

### page 4
Is my state machine for the colorization - in the first version I wanted to match the keyword while reading characters, immediately matching if just the first characters matched, until I realized that it wouldn't work, because then partial keywords, like "**int**eger" would be highlighted wrong.

The next one is the working version - and then I found during programming that I didn't need the "buffer", I could just reference points in the existing buffer (the memory).

### page 5
The top-part is one of the earliest notes, with a list of all the variables I needed. This was before I learned how I could group them together in the `zeropage.asm` file and thus let the code document itself. I needed an overview!

The bottom-part is from much later - I thought I needed another statemachine for the "insert across end-of-line" functionality. In the first version, inserting a space in a line made the last character shift across the edge of the screen, create a new line, and place the character there. Inserting another space would create yet another line, and so on. I wanted the shifting to continue into the same line.

It turned out that I didn't really need a state machine, just a state-variable, remembering where the last insert that created a new line took place. But designing the state machine helped me realize that, before writing unnecessary code, so once again - really recommended!