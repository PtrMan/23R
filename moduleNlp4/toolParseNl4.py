import sys

modelName = '/notebooks/github_vicuna7b/vic7b'
device = 'cpu'

useLm = True # use LM or bypass for fast prototyping?



#############
## UTILS

# tries to parse a string which is numbered at the beginning
# /return None if parsing failed
def tryParseNumbered(s):
    import re
    # s = "1. Example text" # DBG
    match = re.match(r'^\d+\.\s(.+)', s)
    if match:
        s0 = match.group(1)
        return s0
    return None

"""
def tryParseFunctioncall(s):
    import re
    # ex: 'a("blah")'
    match = re.match(r'^(.*)\(\"(.*)\"\)$', s)
    if match:
        return (match.group(1), match.group(2))
    return None
"""

def classifyAndExtractLine(s):
  if s.startswith("* "):
    return ('*', s[2:])
  result = tryParseNumbered(s)
  if result:
    return ('n', result) # number
  
  return None


# given a text from the LMt, extract the response
# returns None if it failed
def extractLmResponse(text):
    z0 = '### Assistant: '
    idx0 = text.find(z0)
    if idx0 == -1:
        return None
    idx1 = idx0+len(z0)
    text0 = text[idx1:]

    # try to find
    z1 = '### Human: '
    idx2 = text0.find(z1)
    if idx2 == -1:
        return text0 # not found - is still valid, just truncated which probably isn't to bad
    text1 = text0[:idx2]

    return text1


"""



# helper to classify a line of the response of subgoal2exec
def classifyLineA(line):
    if line.startswith('```'):
        return ('codeblock', line[3:])
    
    # try to parse the numbered command
    parseRes0 = tryParseNumbered(line)
    if parseRes0 is not None: # is it a valid enumerated command? ex: "2. BLAH"
        return ('enum', parseRes0) # return with 'payload' of numbered
    
    return ('default', line)







# specialized parser which classifies every line
def classifyLinesOfLmResponse(text):
    return list(map(lambda iv: classifyLineA(iv), text.split('\n')))




# group classifed lines into a tree of enum followed by codeblocks
def groupCodes(list0):
    isInCode = False # is the text in a codesection?
    currentCodes = []
    
    res = []
    
    for iLineType, iLineContent in list0:
        if iLineType == 'enum':
            if len(currentCodes) > 0:
                res.append(('enum', currentCodes[:]))
                # flush codes
                currentCodes = []
        elif iLineType == 'codeblock':
            isInCode = not isInCode # switch the state of the code
        elif iLineType == 'default':
            if isInCode: # is this a codeline?
                currentCodes.append(iLineContent) # add this as code to the codes
            else:
                # ignore
                pass
        else:
            pass # ignore
    
    if len(currentCodes) > 0:
        res.append(('enum', currentCodes[:]))
        # flush codes
        currentCodes = []
    
    return res
"""








if useLm:
    import torch
    from transformers import AutoTokenizer, AutoModelForCausalLM, LlamaTokenizer, AutoModel

    

def runPrompt(prompt0, model, tokenizer):
    # see https://huggingface.co/docs/transformers/tasks/language_modeling
    print(f'<run>>{prompt0}')
    inputs0 = tokenizer(prompt0, return_tensors="pt").input_ids
    outputs = model.generate(inputs0, max_new_tokens=120, do_sample=True, top_k=20, top_p=0.95)

    #pipe = pipeline(model=modelName, device_map="cpu")
    #output = pipe("This is a cool example!", do_sample=True, top_k=50, top_p=0.95)

    print(f' ... done')

    x0 = tokenizer.batch_decode(outputs, skip_special_tokens=True)
    x1 = x0[0]
    return x1



# generate prompt
def genPrompt(payload0, partName):
    if partName == 'convNaturalToSimple0': # convert natural language to simpler statements
        # prompt for vincerna-7b
        prompt0 = f'Your task is to describe the sentence as statements in the form of statement("X"). Translate the sentence "{payload0}" to simpler statements!'
    
    
    return prompt0


payload0 = 'Tom is a fat and lazy dancer'
payload0 = 'Tom is fat and has a black hat'
payload0 = sys.argv[1] # first argument

if useLm:
    tokenizer = AutoTokenizer.from_pretrained(modelName, use_fast=False)
    model = AutoModelForCausalLM.from_pretrained(modelName, low_cpu_mem_usage=True) # **kwargs




prompt0 = genPrompt(payload0, 'convNaturalToSimple0') # sentence to simpler relations
prompt0 = f'### Human: {prompt0}\n'

x1 = None
if False or useLm:
    x1 = runPrompt(prompt0, model, tokenizer)

print(f'{x1}') # DBG

if useLm:
    x2 = extractLmResponse(x1)

#x2 = """The answer is
#
#* Marvin is an individual.
#* Marvin is drunk.
#* Marvin is living.
#* Marvin is living on the moon."""
#
#x2 = """The answer is
#
#1. Marvin is an individual.
#2. Marvin is drunk."""

print('')
print('')

print(x2) # DBG

    
resList = [] # list of result
for iLine in x2.split('\n'):
    lineParseRes = classifyAndExtractLine(iLine)
    if lineParseRes:
        type0, content = lineParseRes
        resList.append(content)



import re

# pull out quoted text
resList2 = []
for idx in range(len(resList)):
    result = re.findall(r'"([^"]*)"', resList[idx])
    if result:
        resList2.append(result)
    else:
        resList2.append(resList[idx]) # wasn't able to pull out    
resList = resList2


# remove dot
resList2 = []
for z in resList:
    if z[-1] == '.':
        z = z[:-1]
    resList2.append(z)
resList = resList2


for z in resList:
    print(z)

# write statements in simple natural language to terminal so it is ready for further processed by the reasoner
for z in resList:
    print(f'statement={z}')
