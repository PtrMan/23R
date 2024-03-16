import torch

def transpose2(x):
   return torch.transpose(x, 0, 1)


'''
beta = 0.7

R = torch.rand(2, 3) # retrieval
Wk = torch.rand(4, 3) # key
Wv = torch.rand(4, 3) # value

z0 = beta * ( R @ transpose2(Wk) )
print(z0)
z0 = torch.nn.functional.softmax(z0, dim=-1) # apply softmax to normalize
print(z0)
z0 = z0 @ Wv
print(z0)
z = z0
'''

# "HopfieldLayer"
class HopfieldLayer(torch.nn.Module):
    def __init__(self, n, width, beta=0.1):
        super(HopfieldLayer, self).__init__()
        self.beta = torch.tensor(beta)

        self.n = n # 32
        self.width = width # 50

        self.Wk = torch.nn.Parameter(torch.rand(self.width, self.n)*(1/(self.width*self.n))*0.1) # key
        self.Wv = torch.nn.Parameter(torch.rand(self.width, self.n)*(1/(self.width*self.n))*0.1) # value



    # /param R retrieval
    def forward(self, R):
        z0 = self.beta * (R @ transpose2(self.Wk))
        z0 = torch.nn.functional.softmax(z0, dim=-1)  # Apply softmax
        z = z0 @ self.Wv
        return z

'''
# Example usage
layer0 = HopfieldLayer()

R = torch.rand(5, 16)

z = layer0(R)  # No need to pass Wk and Wv explicitly
print(z)
#print(z.shape)  # Output: torch.Size([2, 4])
'''









# "Hopfield"
class Hopfield(torch.nn.Module):
    def __init__(self, n, width, beta=0.1):
        super(Hopfield, self).__init__()
        self.beta = beta

        self.n = n # number of items
        self.width = width # width of a memory item


        self.Wk = torch.nn.Parameter(torch.rand(self.width, self.n)*(1.0 / (self.width*self.n))*1.0) # key
        self.Wv = torch.nn.Parameter(torch.rand(self.width, self.n)*(1.0 / (self.width*self.n))*0.1) # value
        self.Wq = torch.nn.Parameter(torch.rand(self.n, self.n)*(1.0 / (self.n*self.n))*0.1) # query (is always a square matrix)

    # /param R retrieval
    def forward(self, R, Y):
        z0 = self.beta * R
        z0 = z0 @ self.Wq
        z0 = z0 @ transpose2(self.Wk)
        z0 = z0 @ transpose2(Y)
        z0 = torch.nn.functional.softmax(z0, dim=-1)  # Apply softmax

        z0 = z0 @ Y
        z = z0 @ self.Wv
        return z




class LeakyReLUMlp(torch.nn.Module):
    def __init__(self, input_size, hidden_size, output_size, negative_slope=0.05):
        super(LeakyReLUMlp, self).__init__()
        self.fc1 = torch.nn.Linear(input_size, hidden_size)
        self.leaky_relu = torch.nn.LeakyReLU(negative_slope=negative_slope)
        self.fc2 = torch.nn.Linear(hidden_size, output_size)

        torch.nn.init.xavier_uniform_(self.fc1.weight)
        torch.nn.init.xavier_uniform_(self.fc2.weight)

    def forward(self, x):
        x = self.fc1(x)
        x = self.leaky_relu(x)
        x = self.fc2(x)
        return x

'''
# Example usage
model = LeakyReLUMlp(5*16, 16, 22, 0.05)  # Input size 10, hidden size 16, output size 5, negative slope 0.2
'''






class Linear2(torch.nn.Module):
    def __init__(self, input_size, hidden_size, output_size):
        super(Linear2, self).__init__()
        self.fc1 = torch.nn.Linear(input_size, hidden_size)
        self.fc2 = torch.nn.Linear(hidden_size, output_size)

        torch.nn.init.xavier_uniform_(self.fc1.weight)
        torch.nn.init.xavier_uniform_(self.fc2.weight)

    def forward(self, x):
        x = self.fc1(x)
        x = self.fc2(x)
        return x




# modern hopfield net (simple version without deep learning)
class ModernHopfieldA(object):
    def __init__(self):
        self.beta = 0.6 # beta determines how sharp the datapoints are separated from each other (see modern hopfield paper)
        self.a = None

    def calc(self, zeta):
        #z1 = self.beta * torch.transpose(self.a, 0, 1) @ zeta
        #z2 = torch.nn.functional.softmax(z1, 0)
        z2 = self.calcInternal(zeta)
        zeta_new = self.a @ z2
        zeta = zeta_new
        
        #print(z2) # how much is every exemplar weighted?
        #print(zeta)

        return zeta

    # internal helper : calculates softmax for stimulus
    def calcInternal(self, zeta):
        z1 = self.beta * torch.transpose(self.a, 0, 1) @ zeta
        return torch.nn.functional.softmax(z1, 0)
        
'''
# example usage

modernHopfieldNn = ModernHopfieldA()
modernHopfieldNn.a = a

for zetaIt in range(3): # iterate multiple times to let it converge
    zeta = modernHopfieldNn.calc(zeta)

print(zeta)
'''



