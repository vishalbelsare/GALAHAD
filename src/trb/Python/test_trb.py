from galahad import trb
import numpy as np

# allocate internal data and set default options
trb.initialize()

# set some non-default options
#options = {'print_level' : 3, 'ugo_options' : {'print_level' : 4}}
options = {'print_level' : 1 }
print(options)

# set parameters
p = 4
# set bounds
n = 3
x_l = np.array([-np.inf,-np.inf,0.0])
x_u = np.array([1.1,1.1,1.1])

# set Hessian sparsity
H_type = 'coordinate'
H_ne = 5
H_row = np.array([0,2,1,2,2])
H_col = np.array([0,0,1,1,2])
H_ptr = None

# load data (and optionally non-default options)
trb.load(n, x_l, x_u, H_type, H_ne, H_row, H_col, H_ptr, options=options)

# define objective function and its derivatives
def eval_f(x):
    return (x[0] + x[2] + p)**2 + (x[1] + x[2])**2 + np.cos(x[0])
def eval_g(x):
    return np.array([2.0* ( x[0] + x[2] + p ) - np.sin(x[0]),
                     2.0* ( x[1] + x[2] ),
                     2.0* ( x[0] + x[2] + p ) + 2.0 * ( x[1] + x[2] )])
def eval_h(x):
    return np.array([2. - np.cos(x[0]),2.0,2.0,2.0,4.0])

# set starting point
x = np.array([1.,1.,1.])

# find optimum
x, g = trb.solve(n, H_ne, x, eval_f, eval_g, eval_h)
print("x:",x)
print("g:",g)

# get information
inform = trb.information()
#print(inform)
print("f:",inform['obj'])

# deallocate internal data
trb.terminate()
