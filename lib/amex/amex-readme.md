# manual review 

the result can be improved via a manual 
review.

some CR lines (marking negative balance)
are jumbled. Search for them in all log files
with:
(+ marks lines that could not be matched to an entry)

    ///\+\-\- \.*CR

you can do the same for date and text information for
orphaned amounts. they are shown in STDERR:

slice lengths are unequal: {:date=>[11], :amount=>[11, 2], :text=>[11]}