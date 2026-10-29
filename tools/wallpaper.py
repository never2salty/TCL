# Generates a stylised alpine lake wallpaper (1920x1080).
import numpy as np, sys
from PIL import Image, ImageFilter
W,H=1920,1080
rng=np.random.default_rng(11)
lake=int(H*0.72)
yy=np.arange(H)[:,None].astype(float)

def mpd(n,rough,seed,peaks):
    r=np.random.default_rng(seed)
    size=1
    while size<n: size*=2
    a=np.zeros(size+1); a[0]=r.uniform(-.3,.3); a[-1]=r.uniform(-.3,.3)
    step=size; s=1.0
    while step>1:
        h=step//2
        for i in range(h,size,step):
            a[i]=(a[i-h]+a[i+h])/2+r.normal(0,s)
        s*=rough; step=h
    a=a[:n]
    x=np.linspace(0,1,n)
    for c,w,hgt in peaks: a+=hgt*np.exp(-((x-c)/w)**2)
    return a

sky_top=np.array([52,104,170.]); sky_hor=np.array([196,214,230.])
t=np.clip(yy/lake,0,1)
img=np.repeat((sky_top+(sky_hor-sky_top)*t[...,None]**1.4),W,axis=1)

def layer(line,rock,snowline=None,haze=0.0,seed=0):
    r=np.random.default_rng(seed)
    noise=np.array(Image.fromarray((r.random((H//8,W//8))*255).astype('uint8')).resize((W,H),Image.BICUBIC))/255.
    sm=np.convolve(line,np.ones(25)/25,mode='same')
    for xi in range(W):
        top=int(line[xi])
        if top>=lake: continue
        rows=np.arange(top,lake)
        depth=(rows-top)/max(1,lake-top)
        # light from the left: slope shading
        slope=sm[min(W-1,xi+6)]-sm[max(0,xi-6)]
        light=np.clip(0.85+slope*0.01,0.55,1.15)
        c=np.array(rock)*light*(1-0.35*depth)[:,None]
        c=c*(0.9+0.2*noise[rows,xi])[:,None]
        if snowline is not None:
            sn=((rows < snowline + 60*(noise[rows,xi]-0.5)) & (rows-top < 140+80*noise[rows,xi])).astype(float)
            snow=np.array([236,240,247.])*np.clip(light,0.8,1.05)
            c=c*(1-sn[:,None])+snow*sn[:,None]
        c=c*(1-haze)+sky_hor*haze
        img[top:lake,xi]=c

far=H*0.50-260*mpd(W,0.58,3,[(0.55,0.10,1.2),(0.2,0.12,0.6),(0.85,0.08,0.7)])
layer(far,[118,124,140],snowline=H*0.42,haze=0.35,seed=1)
mid=H*0.60-150*mpd(W,0.55,5,[(0.3,0.08,0.9),(0.72,0.1,0.8)])
layer(mid,[84,92,104],snowline=H*0.50,haze=0.18,seed=2)
forest=H*0.66-40*mpd(W,0.5,8,[])
for xi in range(0,W,7):
    h=rng.integers(20,75); b=forest[xi]
    for d in range(-6,7):
        xx=xi+d
        if 0<=xx<W: forest[xx]=min(forest[xx],b-h*(1-abs(d)/7))
layer(forest,[34,62,46],seed=3)
# shoreline
img[lake-4:lake]=img[lake-4:lake]*0.6
refl=img[2*lake-H:lake][::-1].copy()
w=np.linspace(0,1,H-lake)[:,None,None]
water=np.array([24,58,74.])
img[lake:]=refl*(0.78-0.25*w)+water*(0.22+0.25*w)
im=Image.fromarray(np.clip(img,0,255).astype('uint8'))
lp=im.crop((0,lake,W,H)).filter(ImageFilter.GaussianBlur(2.2))
# ripples
a=np.array(lp).astype(float)
for i in range(0,a.shape[0],5): a[i]*=1.06
im.paste(Image.fromarray(np.clip(a,0,255).astype('uint8')),(0,lake))
im.save(sys.argv[1],quality=86)
