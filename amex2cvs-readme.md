
# About the amex parser/Converter

the text of amex statements contains the data in blocks (slices) like so:

    text
    text
    text

    amount
    amount
    amount

    date
    date
    date

thus, the file is parsed in several passes, see parse method for the steps.

## fields
@parts : date, amount, text

@lines : array of lines with meta info:
Line = Struct.new( :line, :x,:y, :part, :slice, :entry, keyword_init: true) do

@entries = []
Results, one entry per booking / line in statement


@log : copy of lines, obsolete as log can be constructed with meta info in Struct line

@slices : map  part -> array of all line numbers for that part

@sizes: map of just the slice sizes.
@line_entries - still needed?
