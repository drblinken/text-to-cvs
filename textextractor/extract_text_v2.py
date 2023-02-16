import glob
import sys
import os
from pypdf import PdfReader
import re

# this was an experiment with adding the x/y coordination
# of the pdf as information to the extracted txt.
# it allows amex statements to cluster together by their y
# coordinate, but the last statement is jumbled into the
# header.

# sorting by x didn't seem usefull neither.

if len(sys.argv) < 2:
    print("usage: %s <dirname>", argv[0])
    print("extracts all *.pdf in this dir to *.txt in same dir")
    exit(1)

# takes all pdf in dir and creates a text file for each of them.
dir_name = sys.argv[1]

# creates an absolute path, fix
# glob_pattern = os.path.join('.', dir_name, '/*.pdf')
glob_pattern = dir_name+'/*.pdf'

# step 1:glob
# print(glob_pattern)
filenames = glob.glob(glob_pattern)
print(filenames)


class Extractor:
    def __init__(self, reader):
        self.parts = []    # instance variable unique to each instance
        self.reader = reader
        self.page = 0

    def visitor_body(self, text, cm, tm, font_dict, font_size):

        if (not text.endswith("\n")):
            text = text + "\n"

        x = tm[4]
        y = tm[5]
        y = 850-y
        if y < 0:
            print(f"WARNING: larger y:{y}")
        x += self.page*1000
        y += self.page*1000
        text = f'{x:07.2f}:{y:07.2f}-- {text}'

        self.parts.append(text)

    def extract(self):
        for page in self.reader.pages:
            self.page = self.page + 1
            text = page.extract_text()
            page.extract_text(visitor_text=self.visitor_body)
        return ("".join(self.parts))

# step 2: extract text with pypdf


extre = re.compile(r"\.pdf$", re.IGNORECASE)

for filename in filenames:
    reader = PdfReader(filename)
    print(filename)
    txt_filename = extre.sub(".txt", filename)
    print(txt_filename)
    text = Extractor(reader).extract()
    # print(text)
    f = open(txt_filename, "w")
    f.write(text)
    f.close()
