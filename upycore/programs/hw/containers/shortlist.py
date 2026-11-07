a=list(range(6))
print(a[:],a[::-1],a[3::-1],a[-1::-1],a[::-2])
b=a[:]
b[:4]=b[3::-1]
print(a,b)
print(b.copy())
print(b.pop(0));b.insert(2,99);print(b)
for n in range(18):
    a=list(range(n))
    bounds=[None,-n-1,-1,0,1,n,n+1]
    for start in bounds:
        for stop in bounds:
            for step in [1,-1]:
                x=a[start:stop:step]
                # Validate against simple explicit normalization, without slicing.
                if step==1:
                    i=0 if start is None else start
                    j=n if stop is None else stop
                    if start is not None and i<0:i+=n
                    if stop is not None and j<0:j+=n
                    i=max(0,min(n,i));j=max(0,min(n,j))
                else:
                    i=n-1 if start is None else start
                    j=-1 if stop is None else stop
                    if start is not None and i<0:i+=n
                    if stop is not None and j<0:j+=n
                    i=max(-1,min(n-1,i));j=max(-1,min(n-1,j))
                want=[]
                for k in range(i,j,step):want.append(a[k])
                assert x==want,(n,start,stop,step,x,want)
    b=a.copy()
    assert b==a and b is not a
    a[:]=a
    assert a==b
    a[:]=tuple(b)
    assert a==b
print('shortlist smoke passed')

# Snapshot and identity across aliasing replacements and boxed/tagged values.
import gc
o=[]
values=[None,True,False,1.25,2**40,complex(1,2),'abc',o]
a=values[:]
b=a
a[1:5]=a[2:6]
assert b is a and a[4]==complex(1,2)
a[:]=tuple(values)
assert a[-1] is o
r=a[::-1]
assert r[0] is o and r is not a
gc.collect()
assert r[-3]==False and a[-1] is o
for n in [1,2,6,8,9,15,16,17,32,33]:
    a=list(range(n))
    for i in range(n):
        b=a[:]
        got=b.pop(i)
        assert got==i
        b.insert(i,got)
        assert b==a
    for i in [-2147483648,-n-1,-1,0,n,n+1,2147483647]:
        b=a[:]
        b.insert(i,99)
        assert len(b)==n+1 and b.count(99)==1
    assert a[-2147483648:2147483647]==a
    assert a[2147483647:-2147483648:-1]==a[::-1]
class L(list):
    def __getitem__(self,i):
        return 'override'
sub=L([1,2])
assert sub[:]=='override'
assert sub.copy()==[1,2]
print('shortlist alias and GC passed')
