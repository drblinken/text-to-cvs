
dates_re = /((\d\d\.\d\d)(\d\d\.\d\d))|(CR)/
amounts_re = /([\.\d]+,\d\d)/
re = /([A-Z][0-9 A-Z\*\.\/-]{2,})/

re = "([A-Z][0-9 A-Z\*\.\/-]{2,})"
(^#{re}|#{re}$)


(^[A-Z][0-9 A-Z\*\.\/-]{2,}|[A-Z][0-9 A-Z\*\.\/-]{2,}$)


 [1,2,3,6,7,9,12,13,14].slice_when{|prev,cur| cur != prev + 1}.to_a
