# library which exposes custom LM

import torch
import numpy as np

# do LM inference
def lmInferenceByTokens(lm, promptTokens, tokenizer, args):
    seq = promptTokens
    resText = ""

    vocabularySize = len(tokenizer)

    for completionIt in range(args['completionCount']):

        x = seq[-lm.ctxLen:]
        print(x) # DBG
        # * inference
        res0 = lm.inference(x)

        logits = res0['logits']
        logits = logits.reshape(vocabularySize)

        # see https://towardsdatascience.com/how-to-sample-from-language-models-682bceb97277
        temperature = 0.04

        samplingStrategy = 'greedy'

        outputProbs = torch.nn.functional.softmax(logits * (1.0/temperature), 0)

        #print(outputProbs.size())

        # * determine maximal tokenId with use of pytorch
        if samplingStrategy == 'greedy': # argmax sampling
            argMaxTensor = torch.argmax(outputProbs)
            predictedTokenId = argMaxTensor.item()
        else: # random sampling by distribution

            p = np.array(outputProbs)
            p /= p.sum()  # normalize, make sure that sum is close enough to 1.0  .  see https://stackoverflow.com/questions/46539431/np-random-choice-probabilities-do-not-sum-to-1

            #print(p) # DBG

            obj_list = list(range(vocabularySize))
            predictedTokenId = np.random.choice(obj_list, p=p)

        seq.append(predictedTokenId) # * append it to sequence

        
        # convert sequence to text for debugging
        resText = tokenizer.decode(seq)
        print(resText)
    
    return resText



def lmInferenceByText(lm, tokenizer, prompt, args):
    inputs = tokenizer(prompt, return_tensors="pt")
    seq = inputs['input_ids'].detach().numpy()[0].tolist()
    return lmInferenceByTokens(lm, seq, tokenizer, args)

