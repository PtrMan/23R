# cython: linetrace=True

## implementation of using modern hopfield NN for online learning


import torch
import random

from customHopfield2024 import *
from utilsLmA import TokenSliceGen






## generate random vectors for all symbols
symbolsToVecs = []

random.seed(1233)
for z0 in range(63000):
    v = []
    for z in range(22):
        v.append( (random.random() * 2.0 - 1.0) * 1.0 )
    
    # TODO implement function which does rejection sampling for point in unit hypersphere!!!

    symbolsToVecs.append(v)


symbolsToVec2 = []

for iv in symbolsToVecs:
    symbolsToVec2.append( torch.tensor(iv) )

symbolsToVecTensor = torch.stack(symbolsToVec2) # build 2d tensor of translation from symbols to vectors

random.seed()





# https://github.com/opennars/OpenNARS-for-Applications/blob/master/src/Usage.c#L29
class Usage2(object):
    def __init__(self):
        self.timeOfLastRead = 0.0 # absoluteTimeOfLastReadUsage
        self.useCounter = 0

    def reinforce(self, currentTime):
        self.absoluteTimeOfLastUsage = currentTime
        self.useCounter += 1

    def calcUseUtility(self, currentTime):
        recency = max(0, currentTime - self.timeOfLastRead)
        usefulnessToNormalize = (float(usage.useCount)) / (recency + 1.0)
        return usefulnessToNormalize / (usefulnessToNormalize + 1.0)












from transformers import GPT2Tokenizer, GPT2Model
#import torch

tokenizer = GPT2Tokenizer.from_pretrained('gpt2')

vocabularySize = len(tokenizer)






class OnlineLearningHopfieldLm(object):
    def __init__(self):
        self.ctxLen = 12
        self.dat = []

        # metadata for lifelong online-learning
        self.usageArr = [] # array of "Usage2" objects

        # the used hopfield NN
        # will be initialized in train()
        self.hopfield = None
    
    def train(self, tokens):
        self.dat = tokens

        tokensliceGen = TokenSliceGen()
        tokensliceGen.dat = tokens
        tokensliceGen.ctxLen = self.ctxLen

        trainingsetTensors = []

        for idx in range(len(tokensliceGen.dat)-tokensliceGen.ctxLen):

            x, y = tokensliceGen.gen2(idx)
            
            x2 = torch.tensor(x)
            z0 = torch.index_select(symbolsToVecTensor, 0, x2)
            
            


            #z0 = applyPositionalEncoding(z0)

            xVec = torch.flatten(z0)

            trainingsetTensors.append(xVec)

            # add usage tracker for this datum
            usage = Usage2()
            usage.reinforce(0.0) # bump it because we observed it
            self.usageArr.append(usage)


        trainingsetTensor = torch.stack(trainingsetTensors)

        self.hopfield = ModernHopfieldA()
        self.hopfield.beta = 10.0 # 19.5 worked fine, sharp exact predictions
        self.hopfield.a = torch.transpose(trainingsetTensor, 0, 1) # put the whole dataset into the hopfield

        print(f'[dbg  ] size of hopfield matrix={self.hopfield.a.size()}') # DBG

    # /param x is a python list of integers (of context size!)
    # /return {'logits':pytorchTensor}    
    def inference(self, x):
        if len(x) != self.ctxLen:
            raise Exception('')

        x2 = torch.tensor(x)
        z0 = torch.index_select(symbolsToVecTensor, 0, x2)
        
        #z0 = applyPositionalEncoding(z0)

        xVec = torch.flatten(z0)

        xVec = xVec.reshape(xVec.size()[0], 1) # reshape to 1xn matrix, because the Hopfield expects this

        #print(xVec) # DBG

        zeta = xVec
        
        for it in range(10):
            zeta = self.hopfield.calc(zeta)

        # compute how much every sample from the training set is weighted
        weighted = self.hopfield.calcInternal(zeta)
        
        #print(weighted) # DBG

        # * compute probability of predicted next token by multiplying and summing one hot probability of the votes by softmax activation from hopfield network

        logits = torch.zeros(1, vocabularySize)

        for trainingSampleIdx in range(weighted.size()[0]):
            tokenId = self.dat[trainingSampleIdx+self.ctxLen] # predicted token of this detector


            #logits[0][tokenId] = max( (1.0*weighted[trainingSampleIdx].item()) , logits[0][tokenId] )
            # old way was to simply add logits, but that didn't work
            logits[0][tokenId] += (1.0*weighted[trainingSampleIdx].item()) 


            #print(f'{tokenId}  {weighted[trainingSampleIdx].item()}') # DBG

        
        return {'logits':logits}





        

import numpy as np

if __name__ == "__main__":


    lm = OnlineLearningHopfieldLm()

    dat = []
    #dat = [0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 50, 1, 50, 2, 7, 3, 5, 4]

    tokensFilePath = 'C:\\Users\\rober\\fsRoot\\mlDatasets\\tokensB\\tokensB.txt'
    tokensFilePath = 'C:\\Users\\rober\\fsRoot\\mlDatasets\\tokensB\\tokens_forOnlineHopfieldNn.txt'

    dat = []
    with open(tokensFilePath, 'r') as file:
        content = file.read()
        splitContent = content.split(", ")
        dat = [int(item) for item in splitContent]


    lm.train(dat)


    #seq = [0, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 50]

    prompt0 = 'GPT-2 has, like its predecessor GPT-1 and its successors GPT-3 and GPT-'

    prompt0 = '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~GPT-2 and GPT-4 are'
    prompt0 = '~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Ygenerative hell is' # produces interesting results

    prompt0 = '~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~YBERTology-'

    prompt0 = '~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~YCatGPT and GPT-4 are both' # great result!


    prompt0 = '~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~YWhat is the meaning of shalom in english?' # from gpt paper

    # prompt to try on my bot data
    prompt0 = 'download the file https://www.axx.com/a0.pdf and search for the best cancer treatment.'

    # prompt to try on the training set about the GPT's
    prompt0 = '~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~YGPT-4, GPT-3, GPT-2 are'


    # prompt for "creative" writing
    prompt0 = '~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Yintelligence is'

    prompt0 = '~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Y~Yintelligence functions are'



    inputs = tokenizer(prompt0, return_tensors="pt")

    seq = inputs['input_ids'].detach().numpy()[0].tolist()


    for completionIt in range(50):

        x = seq[-lm.ctxLen:]
        print(x) # DBG
        # * inference
        res0 = lm.inference(x)

        logits = res0['logits']
        logits = logits.reshape(vocabularySize)

        # see https://towardsdatascience.com/how-to-sample-from-language-models-682bceb97277
        temperature = 0.12

        outputProbs = torch.nn.functional.softmax(logits * (1.0/temperature), 0)

        #print(outputProbs.size())

        # * determine maximal tokenId with use of pytorch
        if False: # argmax sampling
            argMaxTensor = torch.argmax(outputProbs)
            predictedTokenId = argMaxTensor.item()
        elif True: # random sampling by distribution

            p = np.array(outputProbs)
            p /= p.sum()  # normalize, make sure that sum is close enough to 1.0  .  see https://stackoverflow.com/questions/46539431/np-random-choice-probabilities-do-not-sum-to-1

            #print(p) # DBG

            obj_list = list(range(vocabularySize))
            predictedTokenId = np.random.choice(obj_list, p=p)

        seq.append(predictedTokenId) # * append it to sequence

        
        # convert sequence to text for debugging
        s0 = tokenizer.decode(seq)
        print(s0)





# TODO  :  add functionality to learn online and use "usage" objects to track when a detector did make the correct prediction

