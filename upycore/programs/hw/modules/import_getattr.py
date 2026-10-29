import getattrmod

print(getattrmod.missing)
from getattrmod import missing

print(missing)
d = getattrmod.__dict__
print(d is getattrmod.__dict__)
print(d["sentinel"])
print("missing" in d)
print(d["__name__"])
getattrmod.__dict__ = 1
print(getattrmod.__dict__)
