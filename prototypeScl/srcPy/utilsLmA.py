# utilities for LM

import random

# generator for token slices
class TokenSliceGen(object):
    def __init__(self):
        self.dat = []
        self.ctxLen = 12
    
    def gen(self):
        idx = random.randint(0, len(self.dat)-self.ctxLen-1)
        return self.gen2(idx)
    
    def gen2(self, idx):
        ctx = self.dat[idx:idx+self.ctxLen]
        pred = self.dat[idx+self.ctxLen]

        return (ctx, pred)