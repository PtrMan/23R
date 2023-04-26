# tooling to disambigate the type of a word


# ChatGPT prompt to generate code was "use nltk to check if a word is adjective"

import sys
import nltk

nltk.download('averaged_perceptron_tagger')

#checkWord = 'fat' # word to check
checkWord = sys.argv[1]
posTags = nltk.pos_tag([checkWord])

print(posTags) # DBG

print(f'wordType0={posTags[0][1]}') # print result
