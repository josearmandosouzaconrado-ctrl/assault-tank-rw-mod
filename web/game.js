/* Guerra Fria 3D — mundo aberto em primeira pessoa (Three.js r149, sem outras dependências) */
(()=>{
'use strict';
const $=id=>document.getElementById(id);
const TAU=Math.PI*2;
const clamp=(v,a,b)=>v<a?a:v>b?b:v;
const rand=(a,b)=>a+Math.random()*(b-a);
const pick=a=>a[(Math.random()*a.length)|0];
const smooth=(e0,e1,x)=>{const t=clamp((x-e0)/(e1-e0),0,1);return t*t*(3-2*t);};
function angDiff(a,b){let d=(b-a)%TAU;if(d>Math.PI)d-=TAU;if(d<-Math.PI)d+=TAU;return d;}
function turnTo(a,b,m){const d=angDiff(a,b);return Math.abs(d)<=m?b:a+Math.sign(d)*m;}
function hash(ix,iy){let h=(Math.imul(ix|0,374761393)+Math.imul(iy|0,668265263))|0;h=Math.imul(h^(h>>>13),1274126177);h^=h>>>16;return(h>>>0)/4294967296;}
function vnoise(x,y){const ix=Math.floor(x),iy=Math.floor(y),fx=x-ix,fy=y-iy,sx=fx*fx*(3-2*fx),sy=fy*fy*(3-2*fy);
  const a=hash(ix,iy),b=hash(ix+1,iy),c=hash(ix,iy+1),d=hash(ix+1,iy+1);return a+(b-a)*sx+(c-a)*sy+(a-b-c+d)*sx*sy;}
function fbm(x,y){return vnoise(x,y)*.55+vnoise(x*2.1+17,y*2.1+9)*.3+vnoise(x*4.3+3,y*4.3+41)*.15;}
function segD2(px,py,ax,ay,bx,by){const dx=bx-ax,dy=by-ay,l=dx*dx+dy*dy;let t=l?((px-ax)*dx+(py-ay)*dy)/l:0;t=t<0?0:t>1?1:t;const ex=ax+dx*t-px,ey=ay+dy*t-py;return ex*ex+ey*ey;}
function polyD2(px,py,p){let m=1e18;for(let i=0;i<p.length-1;i++){const d=segD2(px,py,p[i][0],p[i][1],p[i+1][0],p[i+1][1]);if(d<m)m=d;}return m;}
const yawTo=(dx,dz)=>Math.atan2(-dx,-dz); // ângulo de rumo (frente = -Z)

/* ================= nações ================= */
const SIDE={PV:'Pacto de Varsóvia',OTAN:'OTAN'};
const FAC={
  URSS:{n:'União Soviética',s:'URSS',lado:'PV',cor:'#e53935',corpo:'#4d5832',uni:'#6b6a3c',cap:'#4f5530',tank:'T-72',apc:'BMP-1',heli:'Mi-24 Hind',truck:'Ural-375',rifle:'AK-74',rpg:'RPG-7',start:'Wünsdorf (GSFG)',desc:'Grupo de Forças Soviéticas na Alemanha'},
  POL:{n:'Polônia (PRL)',s:'PRL',lado:'PV',cor:'#f5f5f5',corpo:'#5a6640',uni:'#5d6b4a',cap:'#53603f',tank:'T-55A',apc:'OT-64 SKOT',heli:'Mi-2',truck:'Star 266',rifle:'Kbk AKM',rpg:'RPG-7',start:'Szczecin',desc:'República Popular da Polônia'},
  RDA:{n:'Alemanha Oriental (RDA)',s:'RDA',lado:'PV',cor:'#ff9800',corpo:'#5d6544',uni:'#77786a',cap:'#55594a',tank:'T-72M',apc:'BTR-70',heli:'Mi-8',truck:'W50',rifle:'MPi-KM',rpg:'RPG-7',start:'Berlim Oriental',desc:'República Democrática Alemã'},
  RFA:{n:'Alemanha Ocidental (RFA)',s:'RFA',lado:'OTAN',cor:'#fdd835',corpo:'#4b5639',uni:'#59613f',cap:'#3f4630',tank:'Leopard 1',apc:'Marder',heli:'Bo 105',truck:'MAN 5t',rifle:'G3',rpg:'Panzerfaust 44',start:'Hannover',desc:'República Federal da Alemanha'},
  OTAN:{n:'OTAN (Forças dos EUA)',s:'OTAN',lado:'OTAN',cor:'#42a5f5',corpo:'#585c3c',uni:'#6b6a4a',cap:'#565a3c',tank:'M1 Abrams',apc:'M113',heli:'AH-64 Apache',truck:'M35',rifle:'M16A2',rpg:'M72 LAW',start:'Base de Fulda',desc:'Exército dos EUA na Europa'},
};
const FKEYS=['URSS','POL','RDA','RFA','OTAN'];
function star(g,cx,cy,R,r,n=5){g.beginPath();for(let i=0;i<n*2;i++){const a=-Math.PI/2+i*Math.PI/n,rr=i%2?r:R;g.lineTo(cx+Math.cos(a)*rr,cy+Math.sin(a)*rr);}g.closePath();g.fill();}
function drawFlag(g,f,x,y,w,h){
  g.save();g.translate(x,y);
  if(f==='URSS'){g.fillStyle='#cc0000';g.fillRect(0,0,w,h);g.fillStyle='#ffd700';star(g,w*.17,h*.14,h*.09,h*.035);
    const cx=w*.17,cy=h*.38,r=h*.12;g.strokeStyle='#ffd700';g.lineWidth=Math.max(1,h*.045);
    g.beginPath();g.arc(cx,cy,r,Math.PI*.1,Math.PI*1.3);g.stroke();
    g.beginPath();g.moveTo(cx-r*.8,cy+r*.8);g.lineTo(cx+r*.45,cy-r*.45);g.moveTo(cx+r*.05,cy-r*.85);g.lineTo(cx+r*.85,cy-r*.05);g.stroke();}
  else if(f==='POL'){g.fillStyle='#fff';g.fillRect(0,0,w,h/2);g.fillStyle='#dc143c';g.fillRect(0,h/2,w,h/2);}
  else if(f==='RDA'||f==='RFA'){g.fillStyle='#111';g.fillRect(0,0,w,h/3);g.fillStyle='#dd0000';g.fillRect(0,h/3,w,h/3+.5);g.fillStyle='#ffce00';g.fillRect(0,h*2/3,w,h/3);
    if(f==='RDA'){g.strokeStyle='#ffce00';g.lineWidth=Math.max(1,h*.05);g.beginPath();g.arc(w/2,h/2,h*.2,0,TAU);g.stroke();g.fillStyle='#2a5fb0';g.beginPath();g.arc(w/2,h/2,h*.15,0,TAU);g.fill();
      g.strokeStyle='#ffce00';g.lineWidth=Math.max(1,h*.035);g.beginPath();g.moveTo(w/2-h*.09,h/2+h*.09);g.lineTo(w/2+h*.09,h/2-h*.09);g.moveTo(w/2-h*.09,h/2-h*.09);g.lineTo(w/2+h*.09,h/2+h*.09);g.stroke();}}
  else if(f==='OTAN'){g.fillStyle='#004990';g.fillRect(0,0,w,h);g.strokeStyle='#fff';g.lineWidth=Math.max(1,h*.035);
    g.beginPath();g.arc(w/2,h/2,h*.22,0,TAU);g.stroke();g.fillStyle='#fff';star(g,w/2,h/2,h*.3,h*.07,4);
    g.beginPath();g.moveTo(w/2,h*.06);g.lineTo(w/2,h*.94);g.moveTo(w/2-h*.44,h/2);g.lineTo(w/2+h*.44,h/2);g.stroke();}
  g.restore();
}

/* ================= geografia (1 unidade = 1 metro; x = oeste→leste, z = norte→sul) ================= */
const WW=9600,WH=6000;
function seaY(x){const k=x>7400?Math.max(0,1-(x-7400)/500):1;return k*(430+230*Math.sin(x*.0011+1)+110*Math.sin(x*.0037)+40*Math.sin(x*.013));}
const FENCE=[[3050,0],[3000,1500],[3150,2400],[2950,3200],[3200,4000],[3300,4700],[3050,5300],[3200,6000]];
function fenceX(y){for(let i=0;i<FENCE.length-1;i++){const a=FENCE[i],b=FENCE[i+1];if(y>=a[1]&&y<=b[1])return a[0]+(b[0]-a[0])*(y-a[1])/(b[1]-a[1]);}return FENCE[FENCE.length-1][0];}
const WB={x:4250,y:2300,r:235};
const RW=24,ROADW=7,FW=5;
const RIVERS=[
  {n:'Reno',p:[[520,6000],[700,4700],[820,3600],[930,2950],[760,2100],[560,1200],[400,0]]},
  {n:'Elba',p:[[4900,4500],[4600,3800],[4050,3050],[3550,2450],[2950,1600],[2350,1000],[2250,0]]},
  {n:'Oder',p:[[5900,4700],[5650,3700],[5250,2800],[5150,2000],[5250,1300],[5300,0]]},
  {n:'Vístula',p:[[6900,5200],[7050,4100],[7080,3000],[6750,2200],[6350,1300],[6300,0]]},
  {n:'Dnieper',p:[[9500,6000],[9080,4750],[9150,3500],[9350,2000],[9450,0]]},
];
for(const r of RIVERS){let a=1e9,b=1e9,c=-1e9,d=-1e9;for(const q of r.p){a=Math.min(a,q[0]);b=Math.min(b,q[1]);c=Math.max(c,q[0]);d=Math.max(d,q[1]);}r.x0=a-RW;r.y0=b-RW;r.x1=c+RW;r.y1=d+RW;}
const CITY_DEF=[
  ['Hamburgo',2300,'c380','RFA',1],['Hannover',2250,2050,'RFA',1],['Bonn',950,2950,'RFA',1],['Frankfurt',1500,3750,'RFA',1],['Stuttgart',1450,4850,'RFA',0],['Munique',2350,5300,'RFA',1],
  ['Berlim Ocidental',4250,2300,'OTAN',1],['Base de Fulda',2550,3450,'OTAN',0],['Ramstein',750,4300,'OTAN',0],
  ['Rostock',3700,'c200','RDA',0],['Berlim Oriental',4640,2330,'RDA',1],['Magdeburgo',3550,2700,'RDA',0],['Leipzig',3950,3400,'RDA',1],['Dresden',4700,3950,'RDA',1],
  ['Wünsdorf (GSFG)',4700,2780,'URSS',0],
  ['Szczecin',5400,1450,'POL',0],['Gdańsk',6350,'c200','POL',1],['Poznań',5950,2550,'POL',1],['Varsóvia',7000,2900,'POL',1],['Wrocław',5850,3850,'POL',1],['Cracóvia',6750,4750,'POL',1],
  ['Kaliningrado',6950,'c250','URSS',0],['Brest',7950,2950,'URSS',0],['Minsk',8700,2000,'URSS',1],['Lviv',7950,4550,'URSS',0],['Kiev',9000,4500,'URSS',1],['Moscou',9300,1100,'URSS',1],
];
const CITIES=CITY_DEF.map(([n,x,y,f,big])=>({n,x,y:typeof y==='string'?Math.round(seaY(x)+ +y.slice(1)):y,f,f0:f,big,r:big?220:150,prog:0,capFac:null,spawnCd:rand(0,3)}));
const CBN={};CITIES.forEach(c=>CBN[c.n]=c);
const sideOf=c=>FAC[c.f].lado;
const LBL={'Berlim Ocidental':-1,'Berlim Oriental':1,'Gdańsk':-1,'Kaliningrado':1,'Wünsdorf (GSFG)':1,'Magdeburgo':-1};
const ROAD_DEF=[['Hamburgo','Hannover'],['Hannover','Bonn'],['Bonn','Frankfurt'],['Bonn','Ramstein'],['Ramstein','Frankfurt'],['Frankfurt','Stuttgart'],['Stuttgart','Munique'],['Frankfurt','Base de Fulda'],['Hannover','Base de Fulda'],
  ['Base de Fulda','Leipzig'],['Hannover','Magdeburgo'],['Magdeburgo','Berlim Ocidental'],['Berlim Ocidental','Berlim Oriental'],['Berlim Oriental','Rostock'],['Hamburgo','Rostock'],['Berlim Oriental','Wünsdorf (GSFG)'],['Wünsdorf (GSFG)','Dresden'],
  ['Magdeburgo','Leipzig'],['Leipzig','Dresden'],['Munique','Dresden'],['Berlim Oriental','Szczecin'],['Berlim Oriental','Poznań'],['Dresden','Wrocław'],['Szczecin','Gdańsk'],['Szczecin','Poznań'],['Gdańsk','Varsóvia'],['Gdańsk','Kaliningrado'],
  ['Poznań','Varsóvia'],['Poznań','Wrocław'],['Wrocław','Cracóvia'],['Cracóvia','Varsóvia'],['Varsóvia','Brest'],['Cracóvia','Lviv'],['Brest','Minsk'],['Minsk','Moscou'],['Kaliningrado','Minsk'],['Brest','Kiev'],['Lviv','Kiev'],['Kiev','Moscou']];
const ROADS=ROAD_DEF.map(([a,b])=>{const A=CBN[a],B=CBN[b];return{a:A,b:B,ax:A.x,ay:A.y,bx:B.x,by:B.y,x0:Math.min(A.x,B.x)-ROADW,x1:Math.max(A.x,B.x)+ROADW,y0:Math.min(A.y,B.y)-ROADW,y1:Math.max(A.y,B.y)+ROADW};});

const T_GRASS=0,T_FOREST=1,T_WATER=2,T_SEA=3,T_ROAD=4,T_CITY=5,T_FENCE=6;
const TNAME=['Campo','Floresta','Rio','Mar','Estrada','Cidade','Cortina de Ferro'];
const isSea=(x,y)=>x<0||y<0||x>WW||y>WH||y<seaY(x);
function roadDist2(x,y,m=0){let best=1e18;for(const s of ROADS){if(x<s.x0-m||x>s.x1+m||y<s.y0-m||y>s.y1+m)continue;const d=segD2(x,y,s.ax,s.ay,s.bx,s.by);if(d<best)best=d;}return best;}
const onRoad=(x,y)=>roadDist2(x,y)<ROADW*ROADW;
function riverDist2(x,y,m=0){let best=1e18;for(const r of RIVERS){if(x<r.x0-m||x>r.x1+m||y<r.y0-m||y>r.y1+m)continue;const d=polyD2(x,y,r.p);if(d<best)best=d;}return best;}
const onRiver=(x,y)=>riverDist2(x,y)<RW*RW;
function onFence(x,y){if(Math.abs(x-fenceX(y))<FW)return true;const d=Math.hypot(x-WB.x,y-WB.y);return Math.abs(d-WB.r)<FW;}
function cityAt(x,y,m=1){for(const c of CITIES){const dx=x-c.x,dy=y-c.y,r=c.r*m;if(dx*dx+dy*dy<r*r)return c;}return null;}
const forestAt=(x,y)=>fbm(x/700,y/700)>.6;
function terrainAt(x,y){if(isSea(x,y))return T_SEA;if(onRoad(x,y))return T_ROAD;if(onFence(x,y))return T_FENCE;if(onRiver(x,y))return T_WATER;if(cityAt(x,y))return T_CITY;return forestAt(x,y)?T_FOREST:T_GRASS;}

/* ---------- relevo ---------- */
const CH=512,SEG=64,GS=CH/SEG;
function rawH(x,z){
  if(x<-60||z<-60||x>WW+60||z>WH+60)return -10;
  let h=1.5+Math.max(0,fbm(x/900+50,z/900+50)-.45)*75;
  const rd=Math.sqrt(roadDist2(x,z,90));
  let cd=1e9;for(const c of CITIES){const d=Math.hypot(x-c.x,z-c.y)-c.r;if(d<cd)cd=d;}
  h=1.5+(h-1.5)*Math.min(smooth(ROADW+2,ROADW+80,rd),smooth(0,130,cd));
  const rv=Math.sqrt(riverDist2(x,z,50));
  if(rv<RW+25)h=-3.5+(h+3.5)*smooth(RW-8,RW+25,rv);
  if(rd<ROADW+3)h=Math.max(h,1.4);
  const sy=seaY(x);if(z<sy+60)h=-9+(h+9)*smooth(sy-15,sy+60,z);
  return h;
}
const HC=new Map();
function gridH(i,j){const k=i*65536+j;let v=HC.get(k);if(v===undefined){v=rawH(i*GS,j*GS);if(HC.size>300000)HC.clear();HC.set(k,v);}return v;}
function groundH(x,z){const fx=x/GS,fz=z/GS,i=Math.floor(fx),j=Math.floor(fz),tx=fx-i,tz=fz-j;const a=gridH(i,j),b=gridH(i+1,j),c=gridH(i,j+1),d=gridH(i+1,j+1);
  return tx+tz<=1?a+(b-a)*tx+(c-a)*tz:d+(c-d)*(1-tx)+(b-d)*(1-tz);}

/* ---------- prédios das cidades (mesma semente sempre) ---------- */
for(const c of CITIES){c.bld=[];const step=c.big?30:32;
  for(let bz=c.y-c.r;bz<c.y+c.r;bz+=step)for(let bx=c.x-c.r;bx<c.x+c.r;bx+=step){
    const h=hash(bx,bz);if(h<.22)continue;const w=12+h*12,d=12+hash(bz,bx)*12,cx=bx+w/2,cz=bz+d/2;
    const dc=Math.hypot(cx-c.x,cz-c.y);if(dc>c.r-12||dc<26)continue;
    const rr=Math.max(w,d)/2+ROADW+4;if(roadDist2(cx,cz,rr)<rr*rr||riverDist2(cx,cz,40)<(RW+14)**2||isSea(cx,cz))continue;
    if(Math.abs(Math.hypot(cx-WB.x,cz-WB.y)-WB.r)<rr)continue;
    const tall=(c.big?1.6:1)*(1-dc/c.r);const hh=6+hash(bx*3,bz*5)*10+tall*26;
    const pal=h>.8?[[150,80,60],[170,95,70]]:[[175,170,158],[150,148,140],[190,184,170],[130,128,124]];const col=pal[(hash(bz*7,bx*3)*pal.length)|0];
    c.bld.push({x0:cx-w/2,x1:cx+w/2,z0:cz-d/2,z1:cz+d/2,cx,cz,w,d,h:hh,col});}}

/* ---------- textura do chão por bloco ---------- */
function paintChunk(cx,cy){
  const can=document.createElement('canvas');can.width=can.height=CH;const g=can.getContext('2d');const ox=cx*CH,oy=cy*CH;g.translate(-ox,-oy);const C=8;
  for(let j=0;j<CH/C;j++)for(let i=0;i<CH/C;i++){
    const x=ox+i*C,y=oy+j*C,mx=x+4,my=y+4;
    if(mx<0||my<0||mx>WW||my>WH){g.fillStyle='#1d4466';g.fillRect(x,y,C,C);continue;}
    const v=vnoise(mx/220,my/220)*.75+vnoise(mx/40,my/40)*.25,w=hash(i+ox,j+oy)*.1;const city=cityAt(mx,my);
    if(city){const s=104+(v*14|0);g.fillStyle=`rgb(${s},${s},${s-6})`;}
    else if(forestAt(mx,my))g.fillStyle=`rgb(${46+v*14|0},${70+v*16|0},${36+v*8|0})`;
    else{const s=v+w;g.fillStyle=`rgb(${88+s*26|0},${112+s*30|0},${58+s*12|0})`;}
    g.fillRect(x,y,C,C);
    if(!city&&!forestAt(mx,my)&&hash(mx*5,my*3)>.8){g.fillStyle='rgba(60,80,35,.35)';g.fillRect(x+hash(mx,my)*10,y+hash(my,mx)*10,6,6);}
  }
  for(let k=0;k<900;k++){const x=ox+hash(k,cx*31+cy)*CH,y=oy+hash(cy*17+cx,k)*CH;g.fillStyle=hash(k,k+cx)>.5?'rgba(255,255,255,.05)':'rgba(0,0,0,.05)';g.fillRect(x,y,3,3);}
  g.beginPath();g.moveTo(ox-20,oy-20);for(let x=ox-20;x<=ox+CH+20;x+=16)g.lineTo(x,seaY(x)+30);g.lineTo(ox+CH+20,oy-20);g.closePath();
  g.strokeStyle='#cbbd8f';g.lineWidth=40;g.stroke();g.fillStyle='#24557f';g.fill();
  g.lineJoin='round';g.lineCap='round';
  for(const r of RIVERS){g.strokeStyle='#8a8a62';g.lineWidth=RW*2+18;g.beginPath();r.p.forEach((q,k)=>k?g.lineTo(q[0],q[1]):g.moveTo(q[0],q[1]));g.stroke();g.strokeStyle='#2b6596';g.lineWidth=RW*2;g.stroke();}
  g.strokeStyle='#bba878';g.lineWidth=40;g.beginPath();FENCE.forEach((q,k)=>k?g.lineTo(q[0],q[1]):g.moveTo(q[0],q[1]));g.stroke();
  g.strokeStyle='rgba(90,70,40,.5)';g.lineWidth=1;for(let y=Math.max(0,oy-40);y<oy+CH+40;y+=3){const x=fenceX(y);g.beginPath();g.moveTo(x-16,y);g.lineTo(x+16,y);g.stroke();}
  g.strokeStyle='#bba878';g.lineWidth=30;g.beginPath();g.arc(WB.x,WB.y,WB.r+12,0,TAU);g.stroke();
  for(const c of CITIES){if(c.x+c.r<ox||c.x-c.r>ox+CH||c.y+c.r<oy||c.y-c.r>oy+CH)continue;g.fillStyle='rgba(30,30,28,.45)';for(const b of c.bld)g.fillRect(b.x0+2,b.z0+2,b.w+3,b.d+3);
    g.fillStyle='#8f8d86';g.beginPath();g.arc(c.x,c.y,24,0,TAU);g.fill();}
  for(const s of ROADS){g.strokeStyle='#6a6a62';g.lineWidth=ROADW*2+4;g.beginPath();g.moveTo(s.ax,s.ay);g.lineTo(s.bx,s.by);g.stroke();g.strokeStyle='#45453f';g.lineWidth=ROADW*2;g.stroke();}
  g.setLineDash([6,8]);g.strokeStyle='#d8c45e';g.lineWidth=.6;for(const s of ROADS){g.beginPath();g.moveTo(s.ax,s.ay);g.lineTo(s.bx,s.by);g.stroke();}g.setLineDash([]);
  return can;
}
/* ---------- minimapa ---------- */
const MMS=40;const mini=document.createElement('canvas');mini.width=WW/MMS;mini.height=WH/MMS;
function buildMini(){const g=mini.getContext('2d'),im=g.createImageData(mini.width,mini.height);const col=[[92,118,62],[44,76,40],[52,110,160],[28,70,110],[150,150,140],[150,150,145],[200,180,120]];
  for(let y=0;y<mini.height;y++)for(let x=0;x<mini.width;x++){const t=terrainAt(x*MMS+20,y*MMS+20),c=col[t],o=(y*mini.width+x)*4;im.data[o]=c[0];im.data[o+1]=c[1];im.data[o+2]=c[2];im.data[o+3]=255;}
  g.putImageData(im,0,0);}

/* ================= áudio ================= */
let AC=null,master=null,musicG=null,noiseBuf=null,soundOn=true,musicTimer=0,musicPlaying=false,sfxCount=0;
try{soundOn=localStorage.getItem('gfma_som')!=='0';}catch(e){}
function audioInit(){if(AC){if(AC.state==='suspended')AC.resume();return;}try{AC=new (window.AudioContext||window.webkitAudioContext)();master=AC.createGain();master.gain.value=soundOn?1:0;master.connect(AC.destination);
  musicG=AC.createGain();musicG.gain.value=.16;musicG.connect(master);
  noiseBuf=AC.createBuffer(1,AC.sampleRate,AC.sampleRate);const d=noiseBuf.getChannelData(0);for(let i=0;i<d.length;i++)d[i]=Math.random()*2-1;}catch(e){AC=null;}}
function sfx(kind,x,z){if(!AC||!soundOn||sfxCount>12)return;let vol=1;if(G&&G.pl&&x!==undefined){const d=Math.hypot(x-G.pl.x,z-G.pl.z);vol=clamp(1-d/650,0,1);if(vol<=.02)return;}
  sfxCount++;const t=AC.currentTime;const src=AC.createBufferSource();src.buffer=noiseBuf;const f=AC.createBiquadFilter();f.type='lowpass';const gn=AC.createGain();
  const P={shot:[700,.5,.35],rifle:[3000,.22,.07],mg:[2200,.14,.05],boom:[340,1,1.1],rpg:[1300,.35,.7],hit:[2600,.2,.05]}[kind]||[1000,.2,.1];
  f.frequency.setValueAtTime(P[0],t);f.frequency.exponentialRampToValueAtTime(50,t+P[2]);gn.gain.setValueAtTime(P[1]*vol,t);gn.gain.exponentialRampToValueAtTime(.001,t+P[2]);
  src.connect(f);f.connect(gn);gn.connect(master);src.start(t,Math.random()*.5,P[2]+.05);}
// Tema original "Cortina de Ferro" (ré menor)
const THEME=[[62,2],[65,2],[69,3],[67,1],[65,2],[64,2],[62,4],[60,2],[64,2],[67,3],[65,1],[64,2],[62,2],[61,4],[62,2],[65,2],[69,3],[72,1],[74,2],[72,2],[69,4],[70,2],[69,2],[67,2],[64,2],[62,8]];
const BASS=[50,50,48,45,50,53,46,50];
function playMusic(){if(!AC||musicPlaying)return;musicPlaying=true;const e=60/96/2;let t=AC.currentTime+.1;const t0=t;
  for(const [m,d] of THEME){const o=AC.createOscillator(),g=AC.createGain();o.type='triangle';o.frequency.value=440*Math.pow(2,(m-69)/12);g.gain.setValueAtTime(0,t);g.gain.linearRampToValueAtTime(.5,t+.03);g.gain.exponentialRampToValueAtTime(.01,t+d*e*.95);o.connect(g);g.connect(musicG);o.start(t);o.stop(t+d*e);t+=d*e;}
  BASS.forEach((m,i)=>{for(let k=0;k<2;k++){const tt=t0+(i*8+k*4)*e;const o=AC.createOscillator(),g=AC.createGain();o.type='sawtooth';o.frequency.value=440*Math.pow(2,(m-69)/12);g.gain.setValueAtTime(.18,tt);g.gain.exponentialRampToValueAtTime(.005,tt+4*e);const f=AC.createBiquadFilter();f.type='lowpass';f.frequency.value=500;o.connect(f);f.connect(g);g.connect(musicG);o.start(tt);o.stop(tt+4*e);}});
  musicTimer=setTimeout(()=>{musicPlaying=false;if(state==='menu')playMusic();},(t-AC.currentTime)*1000+1500);}
function setSound(on){soundOn=on;try{localStorage.setItem('gfma_som',on?'1':'0');}catch(e){}if(master)master.gain.value=on?1:0;$('bSom').textContent=$('pSom').textContent='Som: '+(on?'ligado':'desligado');}

/* ================= Three.js: cena ================= */
const hud=$('h'),hc=hud.getContext('2d');
let VW=0,VH=0,HDPR=1;
let gfxHigh=false;try{gfxHigh=localStorage.getItem('gfma_gfx')==='1';}catch(e){}
const renderer=new THREE.WebGLRenderer({canvas:$('g'),antialias:gfxHigh,powerPreference:'high-performance'});
const scene=new THREE.Scene();const SKY=0xaabdcc;scene.background=new THREE.Color(SKY);
scene.fog=new THREE.Fog(SKY,170,520);
const camera=new THREE.PerspectiveCamera(70,1,.08,600);camera.rotation.order='YXZ';scene.add(camera);
scene.add(new THREE.HemisphereLight(0xe2ebf3,0x55623a,.8));const sun=new THREE.DirectionalLight(0xfff1d6,.8);sun.position.set(.45,1,.25);scene.add(sun);
const MAXANI=renderer.capabilities.getMaxAnisotropy();
function applyGfx(){renderer.setPixelRatio(Math.min(window.devicePixelRatio||1,gfxHigh?2:1));scene.fog.far=gfxHigh?600:520;camera.far=gfxHigh?650:560;camera.updateProjectionMatrix();resize();
  $('bGfx').textContent='Gráficos: '+(gfxHigh?'bonito':'rápido');}
function resize(){VW=innerWidth;VH=innerHeight;renderer.setSize(VW,VH,false);camera.aspect=VW/VH;camera.updateProjectionMatrix();
  HDPR=Math.min(window.devicePixelRatio||1,2);hud.width=Math.round(VW*HDPR);hud.height=Math.round(VH*HDPR);layoutButtons();}

const MATS={};function M(c,opt){const k=c+(opt?JSON.stringify(opt):'');return MATS[k]||(MATS[k]=new THREE.MeshLambertMaterial(Object.assign({color:c},opt||{})));}
const BGEO={};function BX(w,h,d){const k=w+'_'+h+'_'+d;return BGEO[k]||(BGEO[k]=new THREE.BoxGeometry(w,h,d));}
const CYL={};function CY(rt,rb,h,s=8){const k=rt+'_'+rb+'_'+h+'_'+s;return CYL[k]||(CYL[k]=new THREE.CylinderGeometry(rt,rb,h,s));}
const SPH=new THREE.SphereGeometry(1,8,6);
function part(g,geo,mat,x,y,z){const m=new THREE.Mesh(geo,mat);m.position.set(x,y,z);g.add(m);return m;}

// água
const water=new THREE.Mesh(new THREE.PlaneGeometry(2400,2400),new THREE.MeshLambertMaterial({color:0x2c618f,transparent:true,opacity:.86}));water.rotation.x=-Math.PI/2;water.position.y=-.4;scene.add(water);

// árvores
const treeCrown=new THREE.ConeGeometry(3.2,9,6);treeCrown.translate(0,8.5,0);
const treeTrunk=CY(.35,.45,4.5,5).clone();treeTrunk.translate(0,2.2,0);
const treeMatC=M('#2c4a26'),treeMatT=M('#4a3a28');
const _m4=new THREE.Matrix4(),_q=new THREE.Quaternion(),_v=new THREE.Vector3(),_s=new THREE.Vector3(),_e=new THREE.Euler(),_c=new THREE.Color();

/* ---------- blocos de terreno ---------- */
const chunks=new Map();const chunkQueue=[];
function buildChunk(cx,cz){
  const ox=cx*CH,oz=cz*CH;const grp=new THREE.Group();
  const pos=new Float32Array((SEG+1)*(SEG+1)*3),uv=new Float32Array((SEG+1)*(SEG+1)*2),idx=[];
  const i0=Math.round(ox/GS),j0=Math.round(oz/GS);
  for(let j=0;j<=SEG;j++)for(let i=0;i<=SEG;i++){const k=j*(SEG+1)+i;pos[k*3]=ox+i*GS;pos[k*3+1]=gridH(i0+i,j0+j);pos[k*3+2]=oz+j*GS;uv[k*2]=i/SEG;uv[k*2+1]=1-j/SEG;}
  for(let j=0;j<SEG;j++)for(let i=0;i<SEG;i++){const a=j*(SEG+1)+i,b=a+1,c=a+SEG+1,d=c+1;idx.push(a,c,b,b,c,d);}
  const geo=new THREE.BufferGeometry();geo.setAttribute('position',new THREE.BufferAttribute(pos,3));geo.setAttribute('uv',new THREE.BufferAttribute(uv,2));geo.setIndex(idx);geo.computeVertexNormals();
  const tex=new THREE.CanvasTexture(paintChunk(cx,cz));tex.anisotropy=Math.min(8,MAXANI);
  const ground=new THREE.Mesh(geo,new THREE.MeshLambertMaterial({map:tex}));grp.add(ground);
  // árvores
  const pts=[];
  for(let j=0;j<CH/16;j++)for(let i=0;i<CH/16;i++){const x=ox+i*16+hash(i+ox,j+oz)*14+1,z=oz+j*16+hash(j+oz,i+ox)*14+1;
    if(x<0||z<0||x>WW||z>WH)continue;const fr=forestAt(x,z);if(!fr&&hash(x|0,z|0)<.985)continue;
    if(fr&&hash(z|0,x|0)<.1)continue;const t=terrainAt(x,z);if(t!==T_FOREST&&t!==T_GRASS)continue;if(roadDist2(x,z,20)<(ROADW+6)**2)continue;
    pts.push(x,z,.7+hash(i*7+ox,j*3+oz)*.7);}
  const n=pts.length/3;
  if(n){const im1=new THREE.InstancedMesh(treeCrown,treeMatC,n),im2=new THREE.InstancedMesh(treeTrunk,treeMatT,n);
    for(let k=0;k<n;k++){const x=pts[k*3],z=pts[k*3+1],s=pts[k*3+2];_m4.compose(_v.set(x,groundH(x,z)-.3,z),_q.setFromEuler(_e.set(0,hash(k,cx)*6,0)),_s.set(s,s*rand(.85,1.2),s));im1.setMatrixAt(k,_m4);im2.setMatrixAt(k,_m4);
      _c.setRGB(.15+hash(k,cz)*.06,.25+hash(cz,k)*.1,.13);im1.setColorAt(k,_c);}
    grp.add(im1,im2);}
  // Cortina de Ferro: postes, arame, torres de vigia
  const posts=[],wires=[],towers=[];let prev=null;
  for(let z=Math.max(0,oz);z<Math.min(WH,oz+CH);z+=5){const x=fenceX(z);if(x<ox||x>=ox+CH){prev=null;continue;}
    if(onRoad(x,z)){prev=null;if(onRoad(x,z-5)&&!onRoad(x,z+5))towers.push([x+14,z+8,1]);continue;}
    const y=groundH(x,z);posts.push([x,y,z]);if(prev)wires.push([prev,[x,y,z]]);prev=[x,y,z];
    if(Math.round(z)%400<5)towers.push([x+24,z,0]);}
  if(posts.length){const pm=new THREE.InstancedMesh(BX(.15,3,.15),M('#3a3a36'),posts.length);posts.forEach((p,k)=>{_m4.makeTranslation(p[0],p[1]+1.5,p[2]);pm.setMatrixAt(k,_m4);});grp.add(pm);}
  if(wires.length){const wm=new THREE.InstancedMesh(BX(1,.04,.04),M('#555550'),wires.length*3);let k=0;
    for(const [a,b] of wires){const L=Math.hypot(b[0]-a[0],b[1]-a[1],b[2]-a[2]);for(const hh of [.8,1.7,2.6]){_m4.compose(_v.set((a[0]+b[0])/2,(a[1]+b[1])/2+hh,(a[2]+b[2])/2),_q.setFromEuler(_e.set(0,-Math.atan2(b[2]-a[2],b[0]-a[0]),Math.atan2(b[1]-a[1],Math.hypot(b[0]-a[0],b[2]-a[2])))),_s.set(L,1,1));wm.setMatrixAt(k++,_m4);}}
    grp.add(wm);}
  for(const [x,z,booth] of towers){const y=groundH(x,z);const tg=new THREE.Group();tg.position.set(x,y,z);
    if(booth){part(tg,BX(3,2.6,3),M('#c9c6b8'),0,1.3,0);part(tg,BX(3.6,.3,3.6),M('#5a5a54'),0,2.75,0);part(tg,BX(7,.25,.25),M('#c0392b'),-5,1.1,0);}
    else{part(tg,BX(2.4,9,2.4),M('#b9b6aa'),0,4.5,0);part(tg,BX(3.6,2.2,3.6),M('#9c998e'),0,10,0);part(tg,BX(3.7,.6,3.7),M('#2a2f36'),0,10.3,0);}
    grp.add(tg);}
  // prédios
  for(const c of CITIES){if(c.x+c.r<ox||c.x-c.r>ox+CH||c.y+c.r<oz||c.y-c.r>oz+CH)continue;
    const mine=c.bld.filter(b=>b.cx>=ox&&b.cx<ox+CH&&b.cz>=oz&&b.cz<oz+CH);if(!mine.length)continue;
    const im=new THREE.InstancedMesh(BLDGEO,BLDMAT,mine.length);mine.forEach((b,k)=>{const y=Math.min(groundH(b.x0,b.z0),groundH(b.x1,b.z1),groundH(b.cx,b.cz))-1;
      _m4.compose(_v.set(b.cx,y,b.cz),_q.identity(),_s.set(b.w,b.h+1,b.d));im.setMatrixAt(k,_m4);_c.setRGB(b.col[0]/255,b.col[1]/255,b.col[2]/255);im.setColorAt(k,_c);});grp.add(im);}
  scene.add(grp);return{grp,tex};
}
// textura de janelas para os prédios
const BLDGEO=new THREE.BoxGeometry(1,1,1);BLDGEO.translate(0,.5,0);
const BLDMAT=(()=>{const c=document.createElement('canvas');c.width=c.height=64;const g=c.getContext('2d');g.fillStyle='#fff';g.fillRect(0,0,64,64);
  g.fillStyle='#3a4450';for(let y=4;y<64;y+=16)for(let x=4;x<64;x+=16)g.fillRect(x,y,9,9);const t=new THREE.CanvasTexture(c);return new THREE.MeshLambertMaterial({map:t});})();
function disposeChunk(ch){scene.remove(ch.grp);ch.grp.traverse(o=>{if(o.isMesh&&o.geometry&&o.geometry.attributes.uv&&o.material&&o.material.map===ch.tex){o.geometry.dispose();o.material.dispose();}if(o.isInstancedMesh)o.dispose();});ch.tex.dispose();}
function updateChunks(px,pz,force){
  const ccx=Math.floor(px/CH),ccz=Math.floor(pz/CH);const need=new Set();
  for(let dz=-1;dz<=1;dz++)for(let dx=-1;dx<=1;dx++){const k=(ccx+dx)+','+(ccz+dz);need.add(k);if(!chunks.has(k)&&!chunkQueue.includes(k))chunkQueue.push(k);}
  // carrega o bloco mais próximo primeiro (um por quadro para não travar)
  chunkQueue.sort((a,b)=>{const [ax,az]=a.split(',').map(Number),[bx,bz]=b.split(',').map(Number);return Math.hypot(ax*CH+256-px,az*CH+256-pz)-Math.hypot(bx*CH+256-px,bz*CH+256-pz);});
  let n=force?99:1;while(n-->0&&chunkQueue.length){const k=chunkQueue.shift();if(!need.has(k)||chunks.has(k))continue;const [a,b]=k.split(',').map(Number);chunks.set(k,buildChunk(a,b));}
  for(const [k,ch] of chunks){const [a,b]=k.split(',').map(Number);if(Math.abs(a-ccx)>2||Math.abs(b-ccz)>2){disposeChunk(ch);chunks.delete(k);}}
}
// Muro de Berlim (global)
(()=>{const segs=[];const n=Math.round(TAU*WB.r/3.2);for(let i=0;i<n;i++){const a=i/n*TAU,x=WB.x+Math.cos(a)*WB.r,z=WB.y+Math.sin(a)*WB.r;if(onRoad(x,z))continue;segs.push([x,z,a]);}
  const im=new THREE.InstancedMesh(BX(3.3,3.6,.35),M('#cfccc2'),segs.length);segs.forEach(([x,z,a],k)=>{_m4.compose(_v.set(x,groundH(x,z)+1.6,z),_q.setFromEuler(_e.set(0,-a+Math.PI/2,0)),_s.set(1,1,1));im.setMatrixAt(k,_m4);});scene.add(im);
  const top=new THREE.InstancedMesh(CY(.35,.35,3.3,6),M('#bdbab0'),segs.length);segs.forEach(([x,z,a],k)=>{_m4.compose(_v.set(x,groundH(x,z)+3.5,z),_q.setFromEuler(_e.set(0,-a+Math.PI/2,Math.PI/2,'YXZ')),_s.set(1,1,1));top.setMatrixAt(k,_m4);});scene.add(top);})();
// bandeiras das cidades
for(const c of CITIES){const g=new THREE.Group();const y=groundH(c.x,c.y);g.position.set(c.x,y,c.y);part(g,CY(.15,.2,14,6),M('#cfcfcf'),0,7,0);
  const can=document.createElement('canvas');can.width=96;can.height=60;const tex=new THREE.CanvasTexture(can);
  const fl=new THREE.Mesh(new THREE.PlaneGeometry(4.8,3),new THREE.MeshLambertMaterial({map:tex,side:THREE.DoubleSide}));fl.position.set(2.5,12.4,0);g.add(fl);
  part(g,CY(4,4.5,.6,16),M('#8d8b84'),0,.3,0);scene.add(g);c.flag={g,can,tex,fl};drawCityFlag(c);}
function drawCityFlag(c){const g=c.flag.can.getContext('2d');drawFlag(g,c.f,0,0,96,60);c.flag.tex.needsUpdate=true;}

/* ================= unidades ================= */
const TYPES={
  inf:{hp:80,spd:3.4,range:170,det:300,rel:.8,r:.5,hr:.75,cy:1.1,val:15,arm:1},
  apc:{hp:260,spd:9,range:230,det:360,rel:.22,r:2.2,hr:2.6,cy:1.4,val:40,arm:.25},
  tank:{hp:460,spd:7.5,range:330,det:420,rel:3.4,r:2.6,hr:3.1,cy:1.5,val:70,arm:.04},
  heli:{hp:230,spd:22,range:360,det:520,rel:2.4,r:3,hr:4,cy:0,val:90,arm:.35,alt:34},
  truck:{hp:120,spd:9,range:0,det:0,rel:9,r:2,hr:2.4,cy:1.3,val:50,arm:.6},
};
const WRECK=M('#1e1e1c');
function makeMesh(type,fac){const F=FAC[fac];const g=new THREE.Group();const body=M(F.corpo),dark=M('#22231e'),mark=M(F.cor);
  if(type==='inf'){g.legL=part(g,BX(.2,.9,.24),M('#2b2b24'),-.13,.45,0);g.legR=part(g,BX(.2,.9,.24),M('#2b2b24'),.13,.45,0);
    part(g,BX(.56,.72,.32),M(F.uni),0,1.26,0);part(g,BX(.58,.12,.34),mark,0,1.5,0);part(g,BX(.2,.2,.2),M('#d6b08a'),0,1.74,0);
    const h=part(g,SPH,M(F.cap),0,1.84,0);h.scale.set(.19,.12,.21);part(g,BX(.07,.09,.85),M('#1a1a18'),.2,1.25,-.35);}
  else if(type==='tank'){part(g,BX(3.2,.9,6.6),dark,0,.55,0);part(g,BX(3.4,.75,6.4),body,0,1.2,0);part(g,BX(3.3,.12,1.2),mark,0,1.6,2.6);
    const t=new THREE.Group();t.position.set(0,1.6,.3);g.add(t);part(t,CY(1.35,1.6,.9,10),M(F.corpo,{}),0,.45,0);part(t,BX(.6,.3,.6),mark,.7,.95,.4);
    const br=part(t,CY(.12,.15,5,6),M('#3a3f2c'),0,.45,-2.9);br.rotation.x=Math.PI/2;g.turret=t;}
  else if(type==='apc'){part(g,BX(2.9,.9,6.4),dark,0,.55,0);const h=part(g,BX(3,1.5,6.6),body,0,1.5,0);part(g,BX(3.05,.15,1),mark,0,1.6,-1);
    const t=new THREE.Group();t.position.set(0,2.25,-.6);g.add(t);part(t,CY(.6,.7,.5,8),body,0,.25,0);const br=part(t,CY(.06,.06,2.2,5),M('#222'),0,.3,-1.3);br.rotation.x=Math.PI/2;g.turret=t;}
  else if(type==='truck'){for(const z of [-2,0,2])for(const x of [-1.1,1.1]){const w=part(g,CY(.5,.5,.4,8),dark,x,.5,z);w.rotation.z=Math.PI/2;}
    part(g,BX(2.4,1.8,1.8),body,0,1.6,-2.4);part(g,BX(2.5,.25,4.6),body,0,1.1,.6);part(g,BX(2.5,1.7,4.4),M('#5c5a3c'),0,2.05,.7);part(g,BX(2.42,.5,.05),M('#9fc6d6'),0,2.1,-3.31);}
  else if(type==='heli'){const b=part(g,SPH,body,0,0,0);b.scale.set(1.5,1.4,4.2);part(g,BX(.5,.6,6),body,0,.3,5);part(g,BX(.15,1.8,1),body,0,1.1,7.8);const gl=part(g,SPH,M('#7fa8b8'),0,.4,-3);gl.scale.set(1,.8,1.3);
    part(g,BX(4,.2,.8),body,0,-.2,0);part(g,BX(.4,.4,1.6),mark,1.6,0,0);part(g,BX(.4,.4,1.6),mark,-1.6,0,0);
    const rot=new THREE.Group();rot.position.set(0,1.6,0);g.add(rot);part(rot,BX(15,.06,.45),M('#222'),0,0,0);part(rot,BX(.45,.06,15),M('#222'),0,0,0);g.rotor=rot;}
  return g;}
let G=null,state='menu';let U=[],PRJ=[];
const MAXU=34;
function mkUnit(type,fac,x,z){const T=TYPES[type];const u={type,fac,side:FAC[fac].lado,x,z,y:0,yaw:rand(0,TAU),tyaw:0,hp:T.hp,mhp:T.hp,cd:rand(0,T.rel),T,spd:T.spd,tgt:null,think:rand(0,.4),goal:null,air:type==='heli',dead:false,mv:0,anim:rand(0,10)};
  u.mesh=makeMesh(type,fac);u.y=groundH(x,z)+(u.air?T.alt:0);u.mesh.position.set(x,u.y,z);scene.add(u.mesh);return u;}
function removeUnitMesh(u){if(u.mesh){scene.remove(u.mesh);u.mesh=null;}}

/* ---------- efeitos ---------- */
const FX=[];const fxPool=[];
function getFx(){let o=fxPool.pop();if(!o){o=new THREE.Mesh(SPH,new THREE.MeshBasicMaterial({color:0xffaa33,transparent:true,depthWrite:false,fog:true}));}scene.add(o);return o;}
function explosion(x,y,z,s){for(let i=0;i<2+s*2;i++){const o=getFx();o.material.color.set(i?0x444440:0xffb040);o.material.opacity=i?.7:1;o.position.set(x+rand(-1,1)*s,y+rand(0,1)*s,z+rand(-1,1)*s);o.scale.setScalar(.3);
  FX.push({o,t:0,life:i?rand(1.2,2.2):.35,grow:i?rand(2,4)*s:5*s,rise:i?rand(1,3):0,smoke:!!i});}
  if(G){const d=Math.hypot(x-G.pl.x,z-G.pl.z);G.shake=Math.max(G.shake,clamp(1-d/120,0,1)*s*.15);}sfx('boom',x,z);}
const TRC=[];const trcMat=new THREE.LineBasicMaterial({color:0xffe08a,transparent:true,opacity:.9});
function tracer(ax,ay,az,bx,by,bz){let L=TRC.find(l=>l.t<=0);if(!L){if(TRC.length>40)return;const geo=new THREE.BufferGeometry();geo.setAttribute('position',new THREE.BufferAttribute(new Float32Array(6),3));L={line:new THREE.Line(geo,trcMat),t:0};scene.add(L.line);TRC.push(L);}
  const p=L.line.geometry.attributes.position.array;const f=rand(.2,.5);p[0]=ax+(bx-ax)*f;p[1]=ay+(by-ay)*f;p[2]=az+(bz-az)*f;p[3]=bx;p[4]=by;p[5]=bz;L.line.geometry.attributes.position.needsUpdate=true;L.line.geometry.computeBoundingSphere();L.line.visible=true;L.t=.06;}
function updateFx(dt){for(const f of FX){f.t+=dt;const k=f.t/f.life;f.o.scale.setScalar(.3+f.grow*Math.sqrt(k));f.o.material.opacity=(f.smoke?.6:1)*(1-k);f.o.position.y+=f.rise*dt;}
  for(let i=FX.length-1;i>=0;i--)if(FX[i].t>=FX[i].life){scene.remove(FX[i].o);fxPool.push(FX[i].o);FX.splice(i,1);}
  for(const L of TRC){if(L.t>0){L.t-=dt;if(L.t<=0)L.line.visible=false;}}}

/* ---------- arma em primeira pessoa ---------- */
const vm=new THREE.Group();camera.add(vm);vm.position.set(.14,-.15,-.3);vm.scale.setScalar(.42);vm.rotation.y=.05;
part(vm,BX(.06,.09,.5),M('#1f1f1c'),0,0,0);part(vm,BX(.035,.035,.32),M('#2b2b28'),0,.015,-.4);part(vm,BX(.05,.16,.07),M('#3a2a1c'),0,-.11,-.06);
part(vm,BX(.05,.08,.22),M('#5a3d22'),0,-.02,.33);part(vm,BX(.07,.07,.12),M('#d6b08a'),-.02,-.08,.1);part(vm,BX(.07,.06,.12),M('#d6b08a'),0,-.05,-.22);
const flash=new THREE.Mesh(new THREE.PlaneGeometry(.16,.16),new THREE.MeshBasicMaterial({color:0xffd27a,transparent:true,opacity:.95,depthWrite:false,side:THREE.DoubleSide}));flash.position.set(0,.015,-.6);flash.visible=false;vm.add(flash);
vm.traverse(o=>{if(o.material){o.renderOrder=10;}});

/* ================= jogador ================= */
const UPG=[['arm','Colete e blindagem','+20 de vida a pé e +15% de blindagem dos veículos',150],['gun','Armas melhores','+20% de dano no fuzil e no canhão',180],['eng','Preparo físico e motor','+10% de velocidade a pé e de veículo',140],['mis','Mochila de foguetes','+1 foguete antitanque no máximo e canhão mais rápido',160]];
function footMax(){return 100+20*G.up.arm;}
function rpgMax(){return 3+G.up.mis;}
function makePlayer(x,z){const p={isP:true,type:'inf',fac:G.fac,side:G.side,x,z,y:groundH(x,z),yaw:0,tyaw:0,hp:footMax(),mhp:footMax(),T:TYPES.inf,cd:0,dead:false,mesh:null,veh:null,mv:0};return p;}
function enterVehicle(v){const p=G.pl;G.footHp=p.hp;U=U.filter(u=>u!==v);p.veh={type:v.type,fac:v.fac,mesh:v.mesh,hp:v.hp,mhp:v.mhp};
  p.type=v.type;p.T=TYPES[v.type];const mult=1+.15*G.up.arm;p.mhp=Math.round(TYPES[v.type].hp*1.3*mult);p.hp=Math.round(clamp(v.hp/v.mhp,0,1)*p.mhp);
  p.x=v.x;p.z=v.z;p.yaw=v.yaw;p.speed=0;G.look.yaw=v.yaw;G.look.pitch=0;p.mesh=v.mesh;vm.visible=false;addMsg(`Você entrou no ${FAC[v.fac][v.type]}`);}
function exitVehicle(){const p=G.pl;if(!p.veh)return;const v=mkUnitFromMesh(p.veh,p);v.empty=true;v.hp=p.hp/p.mhp*TYPES[p.veh.type].hp;v.mhp=TYPES[p.veh.type].hp;U.push(v);
  const sx=p.x+Math.cos(p.yaw)*4.5,sz=p.z-Math.sin(p.yaw)*4.5;p.x=sx;p.z=sz;p.type='inf';p.T=TYPES.inf;p.mhp=footMax();p.hp=Math.max(10,Math.min(G.footHp||p.mhp,p.mhp));p.veh=null;p.mesh=null;vm.visible=true;addMsg('Você saiu do veículo');}
function mkUnitFromMesh(veh,p){const u={type:veh.type,fac:veh.fac,side:FAC[veh.fac].lado,x:p.x,z:p.z,y:groundH(p.x,p.z),yaw:p.yaw,tyaw:G.look.yaw,hp:1,mhp:1,cd:0,T:TYPES[veh.type],spd:TYPES[veh.type].spd,tgt:null,think:0,goal:null,air:false,dead:false,mv:0,anim:0,mesh:veh.mesh};return u;}

function addMsg(t,c='#f2d16b'){if(!G)return;G.msgs.unshift({t,c,life:5});if(G.msgs.length>4)G.msgs.length=4;}

/* ---------- dano ---------- */
function damage(u,amt,byP,small){if(u.dead||u.empty&&!byP)return;if(small)amt*=u.T.arm;if(amt<=0)return;
  if(u.isP){u.hp-=amt;G.hurt=Math.min(1,G.hurt+amt/40);G.lastHurt=0;if(u.hp<=0)playerDown();return;}
  u.hp-=amt;u.hitf=.12;if(byP){G.hitMark=.15;}
  if(u.hp<=0)kill(u,byP);}
function kill(u,byP){u.dead=true;if(u.type==='inf'){if(u.mesh){u.mesh.rotation.x=-Math.PI/2;u.mesh.position.y+=.25;}}
  else{explosion(u.x,u.y+1.5,u.z,u.air?1.6:1.3);if(u.mesh){u.mesh.traverse(o=>{if(o.isMesh)o.material=WRECK;});if(u.air){u.mesh.position.y=groundH(u.x,u.z)+.8;u.mesh.rotation.z=.6;}}}
  if(u.mesh)G.wrecks.push({mesh:u.mesh,t:u.type==='inf'?12:35});u.mesh=null;
  if(byP&&!u.empty){G.money+=u.T.val;G.kills++;G.score+=u.T.val;}}
function playerDown(){const p=G.pl;
  if(p.veh){const vx=p.x,vz=p.z;explosion(vx,groundH(vx,vz)+1.5,vz,1.5);if(p.mesh){p.mesh.traverse(o=>{if(o.isMesh)o.material=WRECK;});G.wrecks.push({mesh:p.mesh,t:35});}
    p.veh=null;p.mesh=null;p.type='inf';p.T=TYPES.inf;p.mhp=footMax();p.hp=Math.round((G.footHp||p.mhp)*.4);vm.visible=true;p.x+=3;addMsg('Veículo destruído! Você saltou fora.','#ff7a6a');
    if(p.hp>5)return;}
  p.dead=true;p.hp=0;state='dead';input.reset();setTimeout(()=>{if(state==='dead')$('dead').classList.add('on');},900);}

/* ---------- tiros ---------- */
const _dir=new THREE.Vector3(),_org=new THREE.Vector3();
function unitCenterY(u){return u.air?u.y:u.y+u.T.cy;}
function pickTarget(ox,oy,oz,dx,dy,dz,range,side){let best=null,bt=range;
  for(const u of U){if(u.dead||u.empty||u.isP||u.side===side)continue;const cx=u.x-ox,cy=unitCenterY(u)-oy,cz=u.z-oz;const t=cx*dx+cy*dy+cz*dz;if(t<0||t>bt)continue;
    const px=cx-dx*t,py=cy-dy*t,pz=cz-dz*t;const perp=Math.sqrt(px*px+py*py+pz*pz);if(perp<u.T.hr*.6+t*.022){best=u;bt=t;}}
  return best?{u:best,t:bt}:null;}
function blockedByBuilding(x,y,z){const c=cityAt(x,z,1.05);if(!c)return false;for(const b of c.bld)if(x>b.x0&&x<b.x1&&z>b.z0&&z<b.z1&&y<groundH(b.cx,b.cz)+b.h)return true;return false;}
function hitscanGround(ox,oy,oz,dx,dy,dz,max){for(let t=4;t<max;t+=4){const x=ox+dx*t,y=oy+dy*t,z=oz+dz*t;if(y<groundH(x,z)||blockedByBuilding(x,y,z))return t;}return max;}
function spawnProj(x,y,z,dx,dy,dz,spd,k,side,own,dmg,splash,grav){const mesh=getFx();mesh.material.color.set(k==='rpg'?0xdddddd:0xffd27a);mesh.material.opacity=1;mesh.scale.setScalar(k==='rpg'?.18:.22);mesh.position.set(x,y,z);
  PRJ.push({x,y,z,vx:dx*spd,vy:dy*spd,vz:dz*spd,k,side,own,dmg,splash,grav,life:4,mesh,smk:0});}
function explodeAt(x,y,z,dmg,splash,side,own,direct){explosion(x,y,z,splash/6);
  if(direct)damage(direct,dmg,own,false);
  for(const u of U){if(u.dead||u===direct||u.side===side&&!u.empty)continue;const d=Math.hypot(u.x-x,unitCenterY(u)-y,u.z-z);if(d<splash+u.T.hr*.5)damage(u,dmg*.6*(1-d/(splash+u.T.hr)),own,false);}}
function seg3D2(px,py,pz,ax,ay,az,bx,by,bz){const dx=bx-ax,dy=by-ay,dz=bz-az,l=dx*dx+dy*dy+dz*dz;let t=l?((px-ax)*dx+(py-ay)*dy+(pz-az)*dz)/l:0;t=t<0?0:t>1?1:t;
  const ex=ax+dx*t-px,ey=ay+dy*t-py,ez=az+dz*t-pz;return ex*ex+ey*ey+ez*ez;}
function updateProj(dt){for(const p of PRJ){const ax=p.x,ay=p.y,az=p.z;p.vy-=p.grav*dt;p.x+=p.vx*dt;p.y+=p.vy*dt;p.z+=p.vz*dt;p.life-=dt;p.mesh.position.set(p.x,p.y,p.z);
  if(p.k==='rpg'||p.k==='rocket'){p.smk-=dt;if(p.smk<=0){p.smk=.05;const o=getFx();o.material.color.set(0xcccccc);o.material.opacity=.5;o.position.set(p.x,p.y,p.z);o.scale.setScalar(.2);FX.push({o,t:0,life:.8,grow:1.2,rise:.3,smoke:true});}}
  let hit=null;for(const u of U){if(u.dead||u.side===p.side&&!u.empty)continue;const r=u.T.hr*.75;if(seg3D2(u.x,unitCenterY(u),u.z,ax,ay,az,p.x,p.y,p.z)<r*r){hit=u;p.x=u.x+(ax-u.x)*.3;p.y=unitCenterY(u);p.z=u.z+(az-u.z)*.3;break;}}
  if(hit||p.y<groundH(p.x,p.z)||blockedByBuilding(p.x,p.y,p.z)||p.life<=0){if(p.life>0||hit)explodeAt(p.x,p.y,p.z,p.dmg,p.splash,p.side,p.own,hit);p.done=true;}}
  for(let i=PRJ.length-1;i>=0;i--)if(PRJ[i].done){scene.remove(PRJ[i].mesh);fxPool.push(PRJ[i].mesh);PRJ.splice(i,1);}}

/* ---------- IA ---------- */
function nearestEnemy(u,maxd){let best=null,bd=maxd*maxd;for(const o of U){if(o.dead||o.empty||o.side===u.side)continue;const dx=o.x-u.x,dz=o.z-u.z,d=dx*dx+dz*dz;if(d<bd){bd=d;best=o;}}return best;}
function nearestCity(x,z,pred){let best=null,bd=1e18;for(const c of CITIES){if(!pred(c))continue;const d=(c.x-x)**2+(c.y-z)**2;if(d<bd){bd=d;best=c;}}return best;}
function pushOutBuildings(u,r){const c=cityAt(u.x,u.z,1.08);if(!c)return;for(const b of c.bld){const nx=clamp(u.x,b.x0,b.x1),nz=clamp(u.z,b.z0,b.z1);const dx=u.x-nx,dz=u.z-nz,d2=dx*dx+dz*dz;
  if(d2<r*r){if(d2>1e-6){const d=Math.sqrt(d2);u.x=nx+dx/d*r;u.z=nz+dz/d*r;}else{const l=u.x-b.x0,rr=b.x1-u.x,t=u.z-b.z0,bt=b.z1-u.z;const m=Math.min(l,rr,t,bt);if(m===l)u.x=b.x0-r;else if(m===rr)u.x=b.x1+r;else if(m===t)u.z=b.z0-r;else u.z=b.z1+r;}}}}
const DEEP=-2.6;
function terrainSpeed(u){const h=groundH(u.x,u.z);if(h<-.6)return u.type==='inf'?.45:.4;if(onFence(u.x,u.z))return .3;const rd=roadDist2(u.x,u.z);if(rd<ROADW*ROADW)return 1.25;return forestAt(u.x,u.z)?(u.type==='inf'?.9:.6):1;}
function moveUnit(u,yaw,spd,dt){
  if(!u.air){for(const off of [0,.6,-.6,1.2,-1.2,2,-2,2.8]){const a=yaw+off;if(groundH(u.x-Math.sin(a)*22,u.z-Math.cos(a)*22)>DEEP){yaw=a;break;}}}
  u.yaw=turnTo(u.yaw,yaw,(u.air?1.6:u.type==='inf'?5:1.3)*dt);const v=spd*(u.air?1:u.tf||1);const nx=u.x-Math.sin(u.yaw)*v*dt,nz=u.z-Math.cos(u.yaw)*v*dt;
  if(u.air||groundH(nx,nz)>DEEP){u.x=nx;u.z=nz;}u.x=clamp(u.x,30,WW-30);u.z=clamp(u.z,30,WH-30);u.mv=v;if(!u.air)pushOutBuildings(u,u.T.r);}
function aiFire(u,t,d){const T=u.T;const tx=t.x,ty=unitCenterY(t),tz=t.z;const ox=u.x,oy=u.y+(u.air?-1:u.type==='inf'?1.4:2.2),oz=u.z;
  if(u.type==='inf'||u.type==='apc'){const ch=clamp(.62-d/(T.range*1.3),.05,.5)*(t.isP&&t.type==='inf'?.8:1);const hit=Math.random()<ch;
    const ex=tx+(hit?0:rand(-2,2)),ey=ty+(hit?0:rand(-1,2)),ez=tz+(hit?0:rand(-2,2));tracer(ox,oy,oz,ex,ey,ez);sfx(u.type==='inf'?'rifle':'mg',ox,oz);
    if(hit)damage(t,u.type==='inf'?7:6,false,true);}
  else{let dx=tx-ox,dy=ty-oy,dz=tz-oz;const L=Math.hypot(dx,dy,dz);dx/=L;dy/=L;dz/=L;const sp=u.air?150:220,g=u.air?1:2;dy+=g*(L/sp)/2/sp;
    const sx=rand(-.012,.012),sz=rand(-.012,.012);spawnProj(ox+dx*4,oy+dy*4,oz+dz*4,dx+sx,dy,dz+sz,sp,u.air?'rocket':'shell',u.side,false,u.air?60:130,u.air?5:6,g);
    sfx(u.air?'rpg':'shot',ox,oz);if(!u.air)explosion(ox+dx*6,oy+dy*6,oz+dz*6,.25);}}
function updateAI(u,dt){
  u.think-=dt;
  if(u.think<=0){u.think=.4+Math.random()*.25;u.tf=terrainSpeed(u);
    if(u.type!=='truck')u.tgt=nearestEnemy(u,u.T.det);
    if(!u.tgt&&u.type!=='truck'&&(!u.goal||(u.goal.city&&sideOf(u.goal.city)===u.side&&Math.hypot(u.x-u.goal.x,u.z-u.goal.z)<u.goal.city.r*.6))){
      const c=nearestCity(u.x,u.z,c=>sideOf(c)!==u.side&&Math.hypot(c.x-u.x,c.y-u.z)<1600);
      if(c&&Math.random()<.8)u.goal={x:c.x+rand(-60,60),z:c.y+rand(-60,60),city:c};
      else{const h=u.home||{x:u.x,y:u.z};u.goal={x:h.x+rand(-200,200),z:h.y+rand(-200,200),city:null};}}}
  if(u.type==='truck'){const w=u.path&&u.path[u.pi];if(w){if(Math.hypot(w[0]-u.x,w[1]-u.z)<15)u.pi++;else moveUnit(u,yawTo(w[0]-u.x,w[1]-u.z),u.spd,dt);}else u.arrived=true;return;}
  const t=u.tgt;
  if(t&&!t.dead&&!t.empty){const dx=t.x-u.x,dz=t.z-u.z,d=Math.hypot(dx,dz),ang=yawTo(dx,dz);
    if(u.air)moveUnit(u,ang+(d>u.T.range*.7?0:Math.PI/2),u.spd,dt);
    else if(d>u.T.range*.75)moveUnit(u,ang,u.spd,dt);else if(u.type==='inf'){u.mv=0;u.yaw=turnTo(u.yaw,ang,4*dt);}else moveUnit(u,ang+1.3,u.spd*.3,dt);
    u.tyaw=turnTo(u.tyaw,ang,(u.type==='tank'?.9:3)*dt);
    if(u.cd<=0&&d<u.T.range&&Math.abs(angDiff(u.tyaw,ang))<.12){aiFire(u,t,Math.hypot(d,unitCenterY(t)-u.y));u.cd=u.T.rel*rand(.85,1.3);}}
  else{u.tgt=null;if(u.goal){const d=Math.hypot(u.goal.x-u.x,u.goal.z-u.z);if(d>12)moveUnit(u,yawTo(u.goal.x-u.x,u.goal.z-u.z),u.spd*.85,dt);else{u.mv=0;if(!u.goal.city)u.goal=null;}}
    u.tyaw=turnTo(u.tyaw,u.yaw,1.5*dt);}
}
function syncMesh(u,dt){const m=u.mesh;if(!m)return;const gh=groundH(u.x,u.z);
  if(u.air){const tgtY=gh+u.T.alt;u.y+=(tgtY-u.y)*Math.min(1,dt*1.5);}else u.y=gh;
  m.position.set(u.x,u.y,u.z);m.rotation.y=u.yaw;
  if(!u.air&&u.type!=='inf'){const f=groundH(u.x-Math.sin(u.yaw)*3,u.z-Math.cos(u.yaw)*3),b=groundH(u.x+Math.sin(u.yaw)*3,u.z+Math.cos(u.yaw)*3);m.rotation.x=Math.atan2(f-b,6);}
  if(u.air){m.rotation.x=u.mv?-.12:0;}
  if(m.turret)m.turret.rotation.y=u.tyaw-u.yaw;
  if(m.rotor)m.rotor.rotation.y+=dt*28;
  if(m.legL){u.anim+=dt*u.mv*2.6;const s=Math.sin(u.anim)*.5*(u.mv?1:0);m.legL.rotation.x=s;m.legR.rotation.x=-s;}}

/* ================= cidades / spawn ================= */
function pickType(){const r=Math.random();return r<.2?'tank':r<.36?'apc':r<.92?'inf':'heli';}
function spawnAt(c,type,fac){let x=c.x+rand(-c.r*.6,c.r*.6),z=c.y+rand(-c.r*.6,c.r*.6);for(let i=0;i<6&&(groundH(x,z)<DEEP||blockedByBuilding(x,2,z));i++){x=c.x+rand(-c.r*.6,c.r*.6);z=c.y+rand(-c.r*.6,c.r*.6);}
  const out=[];if(type==='inf'){const n=3+(Math.random()*2|0);for(let i=0;i<n;i++){const u=mkUnit('inf',fac,x+rand(-6,6),z+rand(-6,6));u.home=c;out.push(u);}}else{const u=mkUnit(type,fac,x,z);u.home=c;out.push(u);}
  U.push(...out);return out;}
function updateCities(dt){const p=G.pl;
  for(const c of CITIES){const dP=Math.hypot(c.x-p.x,c.y-p.z);if(dP>1500){c.prog=Math.max(0,c.prog-dt*.05);continue;}
    const own=sideOf(c);let mine=0,other=0,otherFac=null;
    for(const u of U){if(u.dead||u.air||u.empty||u.type==='truck')continue;const dx=u.x-c.x,dz=u.z-c.y;if(dx*dx+dz*dz>c.r*c.r*1.1)continue;if(u.side===own)mine++;else{other++;if(!otherFac||u.isP)otherFac=u.isP?G.fac:u.fac;}}
    if(other>0&&mine===0){const pIn=Math.hypot(p.x-c.x,p.z-c.y)<c.r*1.05&&!p.dead;c.prog+=dt*(.06+.02*Math.min(other,6))*(pIn?1:.3);c.capFac=otherFac;}else c.prog=Math.max(0,c.prog-dt*.12);
    if(c.prog>=1){c.prog=0;c.f=c.capFac;drawCityFlag(c);G.changes++;const ps=FAC[c.f].lado===G.side;addMsg(`${c.n} capturada por ${FAC[c.f].s}!`,ps?'#8fe388':'#ff7a6a');
      if(ps&&Math.hypot(p.x-c.x,p.z-c.y)<c.r*1.2){G.money+=c.big?350:250;G.score+=300;}checkEnd();}
    c.spawnCd-=dt;
    if(c.spawnCd<=0){c.spawnCd=rand(6,11);if(U.length>=MAXU||other>0)continue;if(dP<c.r*.8&&own!==G.side)continue;
      let near=0;for(const u of U)if(!u.dead&&u.side===own&&!u.isP&&!u.empty&&Math.abs(u.x-c.x)<500&&Math.abs(u.z-c.y)<500)near++;
      const cap=(c.big?9:6)+(own!==G.side?2:0);if(near<cap)spawnAt(c,pickType(),c.f);}}
  for(const u of U)if(!u.isP&&!u.mission&&!u.dead&&Math.abs(u.x-p.x)+Math.abs(u.z-p.z)>(u.empty?2400:2000)){u.dead=true;removeUnitMesh(u);}}
function checkEnd(){const mine=CITIES.filter(c=>sideOf(c)===G.side).length;if(mine===CITIES.length)endGame(true);else if(mine===0)endGame(false);}
function endGame(win){state='end';clearSave();input.reset();$('endT').textContent=win?'VITÓRIA!':'DERROTA';
  $('endS').textContent=(win?`${SIDE[G.side]} controla toda a Europa Central.`:`${SIDE[G.side]} perdeu todas as cidades.`)+` Abates: ${G.kills} · Pontos: ${G.score}`;$('endOv').classList.add('on');}

/* ================= missões ================= */
function rndLandNear(x,z,a,b){for(let i=0;i<40;i++){const an=rand(0,TAU),d=rand(a,b);const px=clamp(x+Math.cos(an)*d,80,WW-80),pz=clamp(z+Math.sin(an)*d,80,WH-80);if(groundH(px,pz)>0&&!blockedByBuilding(px,2,pz))return{x:px,z:pz};}return{x,z};}
function newMission(){
  const p=G.pl,hq=G.side==='PV'?'Ordem do Pacto de Varsóvia':'Comando da OTAN';const types=['capture','capture','convoy','defend','spy'];let m=null;
  for(let tries=0;tries<6&&!m;tries++){const ty=pick(types);
    if(ty==='capture'){const c=nearestCity(p.x,p.z,c=>sideOf(c)!==G.side);if(c)m={ty,c,x:c.x,z:c.y,reward:300,txt:`${hq}: capture ${c.n} (${FAC[c.f].s}). Elimine a guarnição e fique dentro da cidade.`};}
    else if(ty==='convoy'){const rs=ROADS.filter(r=>sideOf(r.a)!==G.side&&sideOf(r.b)!==G.side&&segD2(p.x,p.z,r.ax,r.ay,r.bx,r.by)<1300*1300&&Math.hypot(r.ax-r.bx,r.ay-r.by)>500);
      if(rs.length){const r=pick(rs);const L=Math.hypot(r.bx-r.ax,r.by-r.ay);let t=((p.x-r.ax)*(r.bx-r.ax)+(p.z-r.ay)*(r.by-r.ay))/(L*L);t=clamp(t-.25,0,.6);
        const ux=(r.bx-r.ax)/L,uz=(r.by-r.ay)/L;const f=r.a.f;const mk=[];
        for(let i=0;i<4;i++){const x=r.ax+(r.bx-r.ax)*t-ux*i*14,z=r.ay+(r.by-r.ay)*t-uz*i*14;const u=mkUnit(i===3?'apc':'truck',f,x,z);u.yaw=yawTo(ux,uz);u.mission=true;if(i<3){u.path=[[r.bx,r.by]];u.pi=0;}mk.push(u);}
        U.push(...mk);m={ty,units:mk.slice(0,3),reward:450,txt:`${hq}: destrua o comboio ${FAC[f].truck} de ${FAC[f].s} na estrada ${r.a.n} → ${r.b.n} antes que chegue.`};}}
    else if(ty==='defend'){const c=nearestCity(p.x,p.z,c=>sideOf(c)===G.side&&Math.hypot(c.x-p.x,c.y-p.z)<1400);const ec=c&&nearestCity(c.x,c.y,e=>sideOf(e)!==G.side);
      if(c&&ec){const ang=Math.atan2(ec.y-c.y,ec.x-c.x);const mk=[];for(let i=0;i<5;i++){const pt=rndLandNear(c.x+Math.cos(ang)*520,c.y+Math.sin(ang)*520,0,90);const ty2=i<2?'tank':i<4?'inf':pick(['apc','heli']);
          const us=ty2==='inf'?[0,1,2].map(()=>mkUnit('inf',ec.f,pt.x+rand(-5,5),pt.z+rand(-5,5))):[mkUnit(ty2,ec.f,pt.x,pt.z)];us.forEach(u=>{u.mission=true;u.goal={x:c.x,z:c.y,city:c};});mk.push(...us);}
        U.push(...mk);m={ty,c,units:mk,x:c.x,z:c.y,reward:400,txt:`${hq}: ${FAC[ec.f].s} ataca ${c.n}! Destrua a força inimiga.`};}}
    else if(ty==='spy'){const pt=rndLandNear(p.x,p.z,250,600);const c=nearestCity(pt.x,pt.z,()=>true);const ef=G.side==='PV'?pick(['RFA','OTAN']):pick(['URSS','RDA','POL']);
      for(let i=0;i<4;i++){const u=mkUnit(i?'inf':'apc',ef,pt.x+rand(-40,40),pt.z+rand(-40,40));u.mission=true;U.push(u);}
      m={ty,x:pt.x,z:pt.z,hold:0,reward:280,txt:`${hq}: recupere os documentos do agente ${G.side==='PV'?'da Stasi':'da CIA'} perto de ${c.n}. Fique no ponto marcado.`};}}
  if(!m){const c=nearestCity(p.x,p.z,c=>sideOf(c)!==G.side);if(!c)return;m={ty:'capture',c,x:c.x,z:c.y,reward:300,txt:`${hq}: capture ${c.n}.`};}
  G.mis=m;addMsg('Nova missão!','#9fd0ff');}
function updateMission(dt){const m=G.mis;if(!m){G.misCd-=dt;if(G.misCd<=0){G.misCd=2;newMission();}return;}
  let done=false,fail=false;
  if(m.ty==='capture')done=sideOf(m.c)===G.side;
  else if(m.ty==='convoy'){const alive=m.units.filter(u=>!u.dead);if(!alive.length)done=true;else{m.x=alive[0].x;m.z=alive[0].z;if(alive.some(u=>u.arrived)){fail=true;alive.forEach(u=>{u.dead=true;removeUnitMesh(u);});}}}
  else if(m.ty==='defend'){if(m.units.every(u=>u.dead))done=true;else if(sideOf(m.c)!==G.side)fail=true;}
  else if(m.ty==='spy'){if(Math.hypot(G.pl.x-m.x,G.pl.z-m.z)<12){m.hold+=dt;if(m.hold>2.5)done=true;}else m.hold=Math.max(0,m.hold-dt);}
  if(done){G.money+=m.reward;G.score+=m.reward;G.missions++;addMsg(`Missão cumprida! +$${m.reward}`,'#8fe388');G.mis=null;G.misCd=3;save();}
  else if(fail){addMsg('Missão fracassada.','#ff7a6a');G.mis=null;G.misCd=3;}}
const objMarker=new THREE.Group();(()=>{const b=part(objMarker,CY(1.2,1.2,400,10,true),new THREE.MeshBasicMaterial({color:0xffd84a,transparent:true,opacity:.28,depthWrite:false,fog:false}),0,200,0);})();
objMarker.visible=false;scene.add(objMarker);

/* ================= entrada ================= */
const input={keys:{},fire:false,alt:false,altTap:false,ads:false,joy:{on:false,id:null,bx:0,by:0,x:0,y:0},look:{id:null,lx:0,ly:0},fireId:null,
  vec(){let x=0,y=0;const k=this.keys;if(k.KeyA||k.ArrowLeft)x--;if(k.KeyD||k.ArrowRight)x++;if(k.KeyW||k.ArrowUp)y--;if(k.KeyS||k.ArrowDown)y++;
    if(x||y){const m=Math.hypot(x,y);return{x:x/m,y:y/m};}return this.joy.on?{x:this.joy.x,y:this.joy.y}:{x:0,y:0};},
  reset(){this.fire=false;this.alt=false;this.joy.on=false;this.joy.x=this.joy.y=0;this.look.id=null;this.fireId=null;ptrs.clear();}};
const BTN={fire:{r:54},alt:{r:38},ads:{r:30},act:{r:32},shop:{r:32},pause:{r:20}};const MM={w:170,h:106,x:0,y:10};
function layoutButtons(){const s=clamp(Math.min(VW,VH)/400,.75,1.3);BTN.fire.r=54*s;BTN.alt.r=38*s;BTN.ads.r=30*s;BTN.act.r=32*s;BTN.shop.r=32*s;
  BTN.fire.x=VW-BTN.fire.r-26;BTN.fire.y=VH-BTN.fire.r-30;BTN.alt.x=BTN.fire.x-BTN.fire.r-BTN.alt.r-16;BTN.alt.y=VH-BTN.alt.r-18;
  BTN.ads.x=VW-BTN.ads.r-20;BTN.ads.y=BTN.fire.y-BTN.fire.r-BTN.ads.r-20;BTN.act.x=BTN.alt.x-10;BTN.act.y=BTN.alt.y-BTN.alt.r-BTN.act.r-26;
  BTN.shop.x=BTN.act.x-BTN.act.r*2-16;BTN.shop.y=BTN.act.y;
  MM.w=Math.round(clamp(VW*.2,120,220));MM.h=Math.round(MM.w*WH/WW);MM.x=VW-MM.w-10;MM.y=10;BTN.pause.x=MM.x-30;BTN.pause.y=30;}
function actAvailable(){if(!G||!G.pl||G.pl.dead)return null;const p=G.pl;if(p.veh)return'SAIR';let best=null,bd=11*11;
  for(const u of U){if(u.dead||u.isP||(u.type!=='tank'&&u.type!=='apc'))continue;if(!u.empty&&u.side!==G.side)continue;const d=(u.x-p.x)**2+(u.z-p.z)**2;if(d<bd){bd=d;best=u;}}G.actTarget=best;return best?'ENTRAR':null;}
function doAct(){const a=actAvailable();if(a==='SAIR')exitVehicle();else if(a==='ENTRAR'){const v=G.actTarget;if(!v.empty){v.empty=true;}enterVehicle(v);}}
function hitBtn(x,y){if(state!=='play')return null;if(G.mapOpen)return'map';if(x>MM.x&&y<MM.y+MM.h+6&&y>MM.y-4)return'map';
  for(const k of ['fire','alt','ads','pause','act','shop']){if(k==='shop'&&!G.shopOK)continue;if(k==='act'&&!G.actLabel)continue;const b=BTN[k];if(Math.hypot(x-b.x,y-b.y)<b.r+8)return k;}return null;}
const ptrs=new Map();const isTouch=('ontouchstart' in window)||navigator.maxTouchPoints>0;
hud.addEventListener('pointerdown',e=>{e.preventDefault();audioInit();if(state!=='play')return;const x=e.clientX,y=e.clientY;
  if(e.pointerType==='mouse'){if(!document.pointerLockElement&&!G.mapOpen){const b=hitBtn(x,y);if(b==='map'){G.mapOpen=!G.mapOpen;return;}if(b==='pause'){openPause();return;}if(b==='shop'){openShop();return;}if(b==='act'){doAct();return;}
      try{hud.requestPointerLock();}catch(err){}return;}
    if(G.mapOpen){G.mapOpen=false;return;}if(e.button===0)input.fire=true;if(e.button===2)input.ads=!input.ads;return;}
  const b=hitBtn(x,y);
  if(b==='map'){G.mapOpen=!G.mapOpen;return;}if(b==='pause'){openPause();return;}if(b==='shop'){openShop();return;}if(b==='act'){doAct();return;}if(b==='ads'){input.ads=!input.ads;return;}
  if(b==='fire'){input.fire=true;input.fireId=e.pointerId;ptrs.set(e.pointerId,{k:'fire',lx:x,ly:y});return;}
  if(b==='alt'){input.alt=true;input.altTap=true;ptrs.set(e.pointerId,{k:'alt'});return;}
  if(x<VW*.42&&!input.joy.on){const j=input.joy;j.on=true;j.id=e.pointerId;j.bx=x;j.by=y;j.x=j.y=0;ptrs.set(e.pointerId,{k:'joy'});return;}
  ptrs.set(e.pointerId,{k:'look',lx:x,ly:y});},{passive:false});
function lookBy(dx,dy){const s=(input.ads?.0022:.0048);G.look.yaw-=dx*s;G.look.pitch=clamp(G.look.pitch-dy*s,-1.25,1.2);}
window.addEventListener('pointermove',e=>{if(state!=='play')return;
  if(e.pointerType==='mouse'){if(document.pointerLockElement===hud)lookBy(e.movementX*.55,e.movementY*.55);return;}
  const P=ptrs.get(e.pointerId);if(!P)return;
  if(P.k==='joy'){const j=input.joy;let dx=e.clientX-j.bx,dy=e.clientY-j.by;const R=60,m=Math.hypot(dx,dy);if(m>R){j.bx+=dx*(1-R/m);j.by+=dy*(1-R/m);dx=e.clientX-j.bx;dy=e.clientY-j.by;}j.x=dx/R;j.y=dy/R;}
  else if(P.k==='look'||P.k==='fire'){lookBy(e.clientX-P.lx,e.clientY-P.ly);P.lx=e.clientX;P.ly=e.clientY;}});
function ptrUp(e){if(e.pointerType==='mouse'){if(e.button===0)input.fire=false;return;}const P=ptrs.get(e.pointerId);if(!P)return;ptrs.delete(e.pointerId);
  if(P.k==='joy'){input.joy.on=false;input.joy.x=input.joy.y=0;}if(P.k==='fire')input.fire=false;if(P.k==='alt')input.alt=false;}
window.addEventListener('pointerup',ptrUp);window.addEventListener('pointercancel',ptrUp);
hud.addEventListener('contextmenu',e=>e.preventDefault());
window.addEventListener('keydown',e=>{audioInit();input.keys[e.code]=true;if(state!=='play'){if(e.code==='Escape'&&state==='pause')resume();return;}
  if(e.code==='Space'){input.fire=true;e.preventDefault();}if(e.code==='KeyF'){input.alt=true;input.altTap=true;}if(e.code==='KeyE')doAct();if(e.code==='KeyM')G.mapOpen=!G.mapOpen;
  if(e.code==='KeyR'&&G.pl.mag<30)G.pl.reload=2;if(e.code==='KeyB'&&G.shopOK)openShop();if(e.code==='Escape'||e.code==='KeyP')openPause();});
window.addEventListener('keyup',e=>{input.keys[e.code]=false;if(e.code==='Space')input.fire=false;if(e.code==='KeyF')input.alt=false;});
document.addEventListener('pointerlockchange',()=>{if(!document.pointerLockElement&&state==='play'&&!isTouch){input.fire=false;}});
window.addEventListener('blur',()=>{input.keys={};input.reset();if(state==='play')openPause();});
document.addEventListener('visibilitychange',()=>{if(document.hidden&&state==='play')openPause();});
window.onAndroidBack=()=>{if(state==='play'){if(G.mapOpen)G.mapOpen=false;else openPause();}else if(state==='pause')resume();else if(state==='shop')closeShop();};
window.onAndroidPause=()=>{if(state==='play')openPause();if(AC)AC.suspend();};
window.onAndroidResume=()=>{if(AC&&soundOn)AC.resume();};

/* ================= atualização do jogador ================= */
function updatePlayer(dt){const p=G.pl;const j=input.vec();const L=G.look;
  p.cd-=dt;G.lastHurt+=dt;
  if(!p.veh){
    if(G.lastHurt>5&&p.hp<p.mhp)p.hp=Math.min(p.mhp,p.hp+5*dt);
    const tf=terrainSpeed(p);const spd=6.8*(1+.1*G.up.eng)*tf*(input.ads?.55:1);const sy=Math.sin(L.yaw),cy=Math.cos(L.yaw);const fw=-j.y,st=j.x;
    const mx=(-sy*fw+cy*st),mz=(-cy*fw-sy*st);const m=Math.min(1,Math.hypot(mx,mz));
    if(m>.08){const nx=p.x+mx*spd*dt,nz=p.z+mz*spd*dt;if(groundH(nx,nz)>DEEP){p.x=nx;p.z=nz;}else if(groundH(nx,p.z)>DEEP)p.x=nx;else if(groundH(p.x,nz)>DEEP)p.z=nz;p.mv=spd*m;}else p.mv=0;
    p.x=clamp(p.x,30,WW-30);p.z=clamp(p.z,30,WH-30);pushOutBuildings(p,.5);p.yaw=L.yaw;p.y=groundH(p.x,p.z);
    G.bob+=dt*p.mv*1.6;
    if(p.reload>0){p.reload-=dt;if(p.reload<=0)p.mag=30;}
    else if(input.fire&&p.cd<=0){if(p.mag<=0){p.reload=2.2;}else{p.mag--;p.cd=.11;fireRifle();if(p.mag<=0)p.reload=2.2;}}
    if(input.altTap){input.altTap=false;if(G.rpg>0&&p.rpgCd<=0){fireRPG();G.rpg--;p.rpgCd=1.2;}else if(G.rpg<=0)addMsg('Sem foguetes! Reabasteça no quartel.','#ff9a6a');}
    p.rpgCd=(p.rpgCd||0)-dt;}
  else{
    const tf=terrainSpeed(p),maxS=(p.type==='tank'?11:14)*(1+.1*G.up.eng)*tf;const thr=-j.y;
    p.speed+=((thr*maxS)-p.speed)*Math.min(1,dt*1.6);if(Math.abs(thr)<.1)p.speed*=Math.pow(.2,dt);
    p.yaw-=j.x*(p.type==='tank'?.9:1.1)*dt*(p.speed<-.5?-1:1);
    const nx=p.x-Math.sin(p.yaw)*p.speed*dt,nz=p.z-Math.cos(p.yaw)*p.speed*dt;if(groundH(nx,nz)>DEEP){p.x=nx;p.z=nz;}else p.speed*=.3;
    p.x=clamp(p.x,30,WW-30);p.z=clamp(p.z,30,WH-30);const bx=p.x,bz=p.z;pushOutBuildings(p,2.4);if(bx!==p.x||bz!==p.z)p.speed*=.85;
    p.mv=Math.abs(p.speed);p.tyaw=L.yaw;
    if(input.fire&&p.cd<=0){p.cd=(p.type==='tank'?2.6:.5)*(1-.08*G.up.mis);fireCannon();}
    if(input.alt&&(p.mgCd=(p.mgCd||0)-dt)<=0){p.mgCd=.1;fireMG();}input.altTap=false;
    // atropelar soldados inimigos
    for(const u of U)if(!u.dead&&u.type==='inf'&&u.side!==G.side&&Math.abs(p.speed)>3&&Math.hypot(u.x-p.x,u.z-p.z)<3)damage(u,999,true,false);}
  const c=cityAt(p.x,p.z);G.inCity=c&&sideOf(c)===G.side?c:null;G.curCity=c;
  G.shopOK=!!G.inCity&&!nearestEnemy(p,160);
  if(G.inCity&&p.veh&&p.hp<p.mhp)p.hp=Math.min(p.mhp,p.hp+8*dt);
  if(G.inCity&&!p.veh&&G.rpg<rpgMax()){G.rpgT=(G.rpgT||0)+dt;if(G.rpgT>8){G.rpgT=0;G.rpg++;}}
  G.actLabel=actAvailable();}
function camForward(){_dir.set(0,0,-1).applyEuler(camera.rotation);return _dir;}
function fireRifle(){const d=camForward();const spread=input.ads?.003:.012;const dx=d.x+rand(-spread,spread),dy=d.y+rand(-spread,spread),dz=d.z+rand(-spread,spread);const l=Math.hypot(dx,dy,dz);
  const o=camera.position;const hit=pickTarget(o.x,o.y,o.z,dx/l,dy/l,dz/l,420,G.side);const gt=hitscanGround(o.x,o.y,o.z,dx/l,dy/l,dz/l,hit?hit.t:420);
  const end=Math.min(gt,hit?hit.t:420);const ex=o.x+dx/l*end,ey=o.y+dy/l*end,ez=o.z+dz/l*end;
  _v.set(.22,-.2,-.9).applyMatrix4(camera.matrixWorld);tracer(_v.x,_v.y,_v.z,ex,ey,ez);
  if(hit&&hit.t<=gt)damage(hit.u,30*(1+.2*G.up.gun)*(hit.u.type==='inf'&&Math.random()<.15?2:1),true,true);else if(end<420)puffAt(ex,ey,ez);
  G.recoil=1;flash.visible=true;flash.rotation.z=rand(0,TAU);G.flashT=.04;sfx('rifle');G.look.pitch+=input.ads?.004:.008;}
function puffAt(x,y,z){const o=getFx();o.material.color.set(0x8a7e66);o.material.opacity=.7;o.position.set(x,y,z);o.scale.setScalar(.2);FX.push({o,t:0,life:.5,grow:.8,rise:.5,smoke:true});}
function fireRPG(){const d=camForward();const o=camera.position;spawnProj(o.x+d.x*1.2,o.y+d.y*1.2-.1,o.z+d.z*1.2,d.x,d.y+.01,d.z,120,'rpg',G.side,true,300,6,3);sfx('rpg');G.recoil=2;}
function fireCannon(){const d=camForward();const o=camera.position;const p=G.pl;
  if(p.type==='tank'){spawnProj(o.x+d.x*6,o.y+d.y*6-.6,o.z+d.z*6,d.x,d.y+.004,d.z,280,'shell',G.side,true,180*(1+.2*G.up.gun),7,2);explosion(o.x+d.x*6.5,o.y+d.y*6.5-.6,o.z+d.z*6.5,.3);sfx('shot');G.shake=Math.max(G.shake,.25);}
  else fireMG(true);}
function fireMG(heavy){const d=camForward();const o=camera.position;const s=.015;const dx=d.x+rand(-s,s),dy=d.y+rand(-s,s),dz=d.z+rand(-s,s),l=Math.hypot(dx,dy,dz);
  const hit=pickTarget(o.x,o.y,o.z,dx/l,dy/l,dz/l,450,G.side);const gt=hitscanGround(o.x,o.y,o.z,dx/l,dy/l,dz/l,hit?hit.t:450);const end=Math.min(gt,hit?hit.t:450);
  tracer(o.x+d.x*3,o.y-.4,o.z+d.z*3,o.x+dx/l*end,o.y+dy/l*end,o.z+dz/l*end);if(hit&&hit.t<=gt)damage(hit.u,(heavy?60:22)*(1+.2*G.up.gun),true,!heavy);sfx('mg');}

/* ================= câmera / desenho ================= */
const _p=new THREE.Vector3();
function updateCamera(dt){const p=G.pl,L=G.look;G.shake*=Math.pow(.02,dt);const sh=G.shake;
  if(!p.veh){const gh=groundH(p.x,p.z);const bob=Math.sin(G.bob)*.05*(p.mv>.1?1:0);camera.position.set(p.x,Math.max(gh,-1.2)+1.65+bob,p.z);}
  else{const gh=groundH(p.x,p.z);p.y=gh;const m=p.mesh;m.position.set(p.x,gh,p.z);m.rotation.y=p.yaw;const f=groundH(p.x-Math.sin(p.yaw)*3,p.z-Math.cos(p.yaw)*3),b=groundH(p.x+Math.sin(p.yaw)*3,p.z+Math.cos(p.yaw)*3);m.rotation.x=Math.atan2(f-b,6);
    if(m.turret)m.turret.rotation.y=L.yaw-p.yaw;const back=p.type==='tank'?1.4:.8;camera.position.set(p.x+Math.sin(L.yaw)*back,gh+(p.type==='tank'?3.3:3.1),p.z+Math.cos(L.yaw)*back);}
  camera.rotation.set(L.pitch+rand(-sh,sh)*.05,L.yaw+rand(-sh,sh)*.05,0);
  const fov=input.ads?(G.pl.veh?30:42):70;if(Math.abs(camera.fov-fov)>.1){camera.fov+=(fov-camera.fov)*Math.min(1,dt*12);camera.updateProjectionMatrix();}
  G.recoil=Math.max(0,G.recoil-dt*10);vm.position.set(input.ads?0:.16,(input.ads?-.075:-.15)+Math.sin(G.bob*.5)*.004,-.28+G.recoil*.02);vm.rotation.y=input.ads?0:.06;
  if(G.flashT>0){G.flashT-=dt;if(G.flashT<=0)flash.visible=false;}
  water.position.x=Math.round(p.x/50)*50;water.position.z=Math.round(p.z/50)*50;
  sun.position.set(p.x+200,400,p.z+100);sun.target.position.set(p.x,0,p.z);sun.target.updateMatrixWorld();
  const m=G.mis;if(m&&m.x!==undefined){objMarker.visible=true;objMarker.position.set(m.x,groundH(m.x,m.z),m.z);}else objMarker.visible=false;}
function proj(x,y,z){_p.set(x,y,z).project(camera);return{x:(_p.x+1)/2*VW,y:(1-_p.y)/2*VH,behind:_p.z>1};}
function bar(x,y,w,h,v,c){hc.fillStyle='rgba(0,0,0,.55)';hc.fillRect(x,y,w,h);hc.fillStyle=c;hc.fillRect(x+1,y+1,(w-2)*clamp(v,0,1),h-2);}
function drawMiniMap(x,y,w,h,full){const g=hc;g.drawImage(mini,x,y,w,h);const k=w/WW;
  for(const c of CITIES){g.fillStyle=FAC[c.f].cor;g.strokeStyle='#000';g.lineWidth=1;const r=full?(c.big?7:5):(c.big?3.2:2.4);g.beginPath();g.arc(x+c.x*k,y+c.y*k,r,0,TAU);g.fill();g.stroke();
    if(full){g.font='bold 12px system-ui,Arial';const al=LBL[c.n]||0;g.textAlign=al<0?'right':al>0?'left':'center';const lx=x+c.x*k+al*9,ly=y+c.y*k-(al?-4:10);g.lineWidth=3;g.strokeStyle='rgba(0,0,0,.8)';g.strokeText(c.n,lx,ly);g.fillStyle='#fff';g.fillText(c.n,lx,ly);}}
  g.strokeStyle='rgba(30,30,30,.9)';g.lineWidth=full?2:1;g.beginPath();FENCE.forEach((q,i)=>i?g.lineTo(x+q[0]*k,y+q[1]*k):g.moveTo(x+q[0]*k,y+q[1]*k));g.stroke();
  if(full)for(const u of U){if(u.dead||u.isP||u.empty)continue;g.fillStyle=u.side===G.side?'#7fd3ff':'#ff4a3a';g.fillRect(x+u.x*k-1.5,y+u.z*k-1.5,3,3);}
  const m=G.mis;if(m&&m.x!==undefined){g.strokeStyle='#ffd84a';g.lineWidth=2;g.beginPath();g.arc(x+m.x*k,y+m.z*k,full?10:5,0,TAU);g.stroke();}
  const p=G.pl;g.save();g.translate(x+p.x*k,y+p.z*k);g.rotate(Math.atan2(-Math.cos(G.look.yaw),-Math.sin(G.look.yaw)));g.fillStyle='#fff';g.strokeStyle='#000';g.beginPath();const z=full?9:5;g.moveTo(z,0);g.lineTo(-z*.7,-z*.7);g.lineTo(-z*.7,z*.7);g.closePath();g.fill();g.stroke();g.restore();
  g.strokeStyle='#f2d16b';g.lineWidth=1.5;g.strokeRect(x,y,w,h);}
function wrap(s,w){const words=s.split(' '),out=[];let l='';for(const x of words){const tt=l?l+' '+x:x;if(hc.measureText(tt).width>w&&l){out.push(l);l=x;}else l=tt;}if(l)out.push(l);return out;}
function drawHUD(t){const g=hc;g.setTransform(HDPR,0,0,HDPR,0,0);g.clearRect(0,0,VW,VH);if(!G||!G.pl)return;const p=G.pl,F=FAC[G.fac];
  if(G.hurt>0){const gr=g.createRadialGradient(VW/2,VH/2,VH*.3,VW/2,VH/2,VH*.85);gr.addColorStop(0,'rgba(160,0,0,0)');gr.addColorStop(1,`rgba(160,0,0,${.55*G.hurt})`);g.fillStyle=gr;g.fillRect(0,0,VW,VH);}
  // marcadores de inimigos
  for(const u of U){if(u.dead||u.empty||u.isP||u.side===G.side)continue;const d=Math.hypot(u.x-p.x,u.z-p.z);if(d>320)continue;const s=proj(u.x,unitCenterY(u)+(u.type==='inf'?1.2:u.air?3:3.2),u.z);if(s.behind||s.x<0||s.x>VW||s.y<0||s.y>VH)continue;
    g.fillStyle='rgba(255,60,40,.85)';g.beginPath();g.moveTo(s.x,s.y);g.lineTo(s.x-5,s.y-8);g.lineTo(s.x+5,s.y-8);g.fill();
    if(u.hp<u.mhp&&d<150){g.fillStyle='rgba(0,0,0,.6)';g.fillRect(s.x-14,s.y-14,28,4);g.fillStyle='#ff5b4a';g.fillRect(s.x-14,s.y-14,28*u.hp/u.mhp,4);}}
  // objetivo
  const m=G.mis;if(m&&m.x!==undefined){let s=proj(m.x,groundH(m.x,m.z)+6,m.z);let x=s.x,y=s.y;if(s.behind){x=VW-x;y=VH-8;}x=clamp(x,30,VW-30);y=clamp(y,40,VH-30);
    g.fillStyle='#ffd84a';g.beginPath();g.arc(x,y,7,0,TAU);g.fill();g.font='bold 12px system-ui,Arial';g.textAlign='center';g.lineWidth=3;g.strokeStyle='rgba(0,0,0,.8)';const dm=Math.round(Math.hypot(m.x-p.x,m.z-p.z));
    g.strokeText(dm+' m',x,y-12);g.fillText(dm+' m',x,y-12);if(m.ty==='spy'&&m.hold>0){g.strokeStyle='#ffd84a';g.lineWidth=4;g.beginPath();g.arc(VW/2,VH/2,26,-Math.PI/2,-Math.PI/2+TAU*m.hold/2.5);g.stroke();}}
  // mira
  g.strokeStyle='rgba(255,255,255,.9)';g.lineWidth=2;const cx=VW/2,cy=VH/2,gap=input.ads?3:8;
  if(p.veh&&p.type==='tank'){g.beginPath();g.moveTo(cx-30,cy);g.lineTo(cx-8,cy);g.moveTo(cx+8,cy);g.lineTo(cx+30,cy);g.moveTo(cx,cy+8);g.lineTo(cx,cy+30);for(let i=1;i<4;i++){g.moveTo(cx-6,cy+8+i*7);g.lineTo(cx+6,cy+8+i*7);}g.stroke();
    if(p.cd>0){g.strokeStyle='#ffb040';g.beginPath();g.arc(cx,cy,40,-Math.PI/2,-Math.PI/2+TAU*(1-p.cd/(2.6*(1-.08*G.up.mis))));g.stroke();}}
  else{g.beginPath();g.moveTo(cx-gap-8,cy);g.lineTo(cx-gap,cy);g.moveTo(cx+gap,cy);g.lineTo(cx+gap+8,cy);g.moveTo(cx,cy-gap-8);g.lineTo(cx,cy-gap);g.moveTo(cx,cy+gap);g.lineTo(cx,cy+gap+8);g.stroke();}
  if(G.hitMark>0){g.strokeStyle='#ff4030';g.lineWidth=2.5;g.beginPath();for(const [a,b] of [[-1,-1],[1,-1],[-1,1],[1,1]]){g.moveTo(cx+a*6,cy+b*6);g.lineTo(cx+a*13,cy+b*13);}g.stroke();}
  // painel
  g.fillStyle='rgba(10,12,9,.55)';g.fillRect(8,8,250,74);drawFlag(g,G.fac,14,14,42,27);g.textAlign='left';g.font='bold 13px system-ui,Arial';g.fillStyle='#fff';
  const wpn=p.veh?`${F[p.veh.type]||p.veh.type}`:`${F.rifle} · ${p.reload>0?'recarregando…':p.mag+'/30'}`;g.fillText(wpn,62,25);
  g.font='12px system-ui,Arial';g.fillStyle='#f2d16b';g.fillText(`$${G.money}  ☠ ${G.kills}  ★ ${G.missions}  🚀 ${G.rpg}/${rpgMax()}`,62,41);
  bar(14,48,238,12,p.hp/p.mhp,p.hp/p.mhp>.35?'#6fd35f':'#ff5040');g.fillStyle='#fff';g.font='10px system-ui,Arial';g.fillText(`${p.veh?'Blindagem':'Vida'} ${Math.ceil(p.hp)}/${p.mhp}`,18,58);
  const defcon=clamp(5-Math.floor(G.changes/3),1,5),dc=['','#fff','#ff3b30','#ffd60a','#34c759','#0a84ff'][defcon];
  g.fillStyle=dc;g.font='bold 11px system-ui,Arial';g.fillText(`DEFCON ${defcon}`,14,76);g.fillStyle='#ccc';g.font='11px system-ui,Arial';const mine=CITIES.filter(c=>sideOf(c)===G.side).length;
  g.fillText(`${SIDE[G.side]}: ${mine}/${CITIES.length} · ${G.curCity?G.curCity.n:TNAME[terrainAt(p.x,p.z)]}`,82,76);
  if(G.curCity&&G.curCity.prog>0){bar(VW/2-90,VH-26,180,10,G.curCity.prog,FAC[G.curCity.capFac]?FAC[G.curCity.capFac].cor:'#fff');g.textAlign='center';g.fillStyle='#fff';g.font='bold 11px system-ui,Arial';g.fillText('Capturando '+G.curCity.n,VW/2,VH-30);}
  if(G.mis){g.font='12px system-ui,Arial';const maxw=Math.max(160,Math.min(VW-MM.w-320,520));const lines=wrap(G.mis.txt,maxw);const bw=maxw+16,bx=Math.max(266,(VW-bw)/2-MM.w/2);
    g.fillStyle='rgba(10,12,9,.6)';g.fillRect(bx,8,bw,8+lines.length*16);g.fillStyle='#ffe28a';g.textAlign='left';lines.forEach((l,i)=>g.fillText(l,bx+8,22+i*16));}
  g.textAlign='center';g.font='bold 15px system-ui,Arial';G.msgs.forEach((mm,i)=>{g.globalAlpha=clamp(mm.life,0,1);g.lineWidth=4;g.strokeStyle='rgba(0,0,0,.8)';g.strokeText(mm.t,VW/2,VH*.28+i*22);g.fillStyle=mm.c;g.fillText(mm.t,VW/2,VH*.28+i*22);});g.globalAlpha=1;
  drawMiniMap(MM.x,MM.y,MM.w,MM.h,false);
  const btn=(b,label,on,col)=>{g.globalAlpha=on?.85:.4;g.fillStyle=col;g.beginPath();g.arc(b.x,b.y,b.r,0,TAU);g.fill();g.strokeStyle='rgba(255,255,255,.7)';g.lineWidth=2;g.stroke();
    g.globalAlpha=1;g.fillStyle='#fff';g.font=`bold ${Math.round(b.r*.3)}px system-ui,Arial`;g.textAlign='center';g.fillText(label,b.x,b.y+b.r*.11);};
  btn(BTN.fire,p.veh?(p.type==='tank'?'CANHÃO':'FOGO'):'FOGO',p.cd<=0,input.fire?'#c0392b':'rgba(150,40,30,.8)');
  btn(BTN.alt,p.veh?'METRAL.':'RPG '+G.rpg,p.veh||G.rpg>0,'rgba(30,80,150,.8)');
  btn(BTN.ads,'MIRA',true,input.ads?'rgba(200,160,40,.9)':'rgba(60,60,60,.7)');
  if(G.actLabel)btn(BTN.act,G.actLabel,true,'rgba(40,120,50,.9)');
  if(G.shopOK)btn(BTN.shop,'QUARTEL',true,'rgba(120,90,30,.9)');
  g.fillStyle='rgba(10,12,9,.6)';g.beginPath();g.arc(BTN.pause.x,BTN.pause.y,BTN.pause.r,0,TAU);g.fill();g.fillStyle='#fff';g.fillRect(BTN.pause.x-6,BTN.pause.y-7,4,14);g.fillRect(BTN.pause.x+2,BTN.pause.y-7,4,14);
  const j=input.joy;if(j.on){g.globalAlpha=.45;g.strokeStyle='#fff';g.lineWidth=3;g.beginPath();g.arc(j.bx,j.by,60,0,TAU);g.stroke();g.fillStyle='#fff';g.beginPath();g.arc(j.bx+clamp(j.x,-1,1)*60,j.by+clamp(j.y,-1,1)*60,24,0,TAU);g.fill();g.globalAlpha=1;}
  else if(isTouch&&G.t<30){g.globalAlpha=.25;g.strokeStyle='#fff';g.lineWidth=3;g.beginPath();g.arc(110,VH-110,60,0,TAU);g.stroke();g.font='12px system-ui,Arial';g.fillStyle='#fff';g.textAlign='center';g.fillText('mover',110,VH-110);g.fillText('arraste aqui para olhar →',VW*.55,VH-40);g.globalAlpha=1;}
  if(!isTouch&&!document.pointerLockElement&&!G.mapOpen){g.fillStyle='rgba(0,0,0,.6)';g.fillRect(VW/2-150,VH/2+30,300,26);g.fillStyle='#fff';g.font='13px system-ui,Arial';g.textAlign='center';g.fillText('Clique para controlar a câmera com o mouse',VW/2,VH/2+48);}
  if(G.mapOpen){g.fillStyle='rgba(0,0,0,.82)';g.fillRect(0,0,VW,VH);const w=Math.min(VW-30,(VH-50)*WW/WH),h=w*WH/WW;drawMiniMap((VW-w)/2,30,w,h,true);
    g.fillStyle='#fff';g.font='bold 13px system-ui,Arial';g.textAlign='center';g.fillText('MAPA DA EUROPA CENTRAL — toque para fechar',VW/2,20);}}

/* ================= laço principal ================= */
let last=0;
function step(now){requestAnimationFrame(step);const t=now/1000;const dt=Math.min(.05,t-(last||t));last=t;sfxCount=Math.max(0,sfxCount-dt*90);
  if(!G){hc.setTransform(1,0,0,1,0,0);hc.clearRect(0,0,hud.width,hud.height);return;}
  if(state==='play'&&!G.mapOpen){G.t+=dt;G.hurt=Math.max(0,G.hurt-dt*.8);G.hitMark-=dt;
    updatePlayer(dt);
    for(const u of U){if(u.dead||u.isP)continue;if(u.empty){syncMesh(u,dt);continue;}u.cd-=dt;updateAI(u,dt);syncMesh(u,dt);}
    // separação entre unidades
    for(let i=0;i<U.length;i++){const a=U[i];if(a.dead||a.air)continue;for(let k=i+1;k<U.length;k++){const b=U[k];if(b.dead||b.air)continue;const dx=b.x-a.x,dz=b.z-a.z,rr=a.T.r+b.T.r,d2=dx*dx+dz*dz;
      if(d2<rr*rr&&d2>1e-4){const d=Math.sqrt(d2),o=(rr-d)/2,nx=dx/d,nz=dz/d;const wa=a.isP?.25:a.empty?.1:1,wb=b.isP?.25:b.empty?.1:1;a.x-=nx*o*wa;a.z-=nz*o*wa;b.x+=nx*o*wb;b.z+=nz*o*wb;}}}
    updateProj(dt);
    U=U.filter(u=>{if(u.dead&&!u.isP){if(u.mesh)removeUnitMesh(u);return false;}return true;});
    for(const w of G.wrecks)w.t-=dt;G.wrecks=G.wrecks.filter(w=>{if(w.t<=0){scene.remove(w.mesh);return false;}return true;});
    for(const mm of G.msgs)mm.life-=dt;G.msgs=G.msgs.filter(mm=>mm.life>0);
    if(state==='play'){updateCities(dt);updateMission(dt);}
    G.saveT-=dt;if(G.saveT<=0){G.saveT=15;save();}}
  updateFx(dt);updateChunks(G.pl.x,G.pl.z,false);updateCamera(dt);
  renderer.render(scene,camera);drawHUD(t);}

/* ================= salvar / carregar ================= */
const SKEY='gfma3d_save_v1';
function save(){if(!G||state==='end'||!G.pl||G.pl.dead)return;try{localStorage.setItem(SKEY,JSON.stringify({fac:G.fac,money:G.money,kills:G.kills,score:G.score,missions:G.missions,changes:G.changes,up:G.up,rpg:G.rpg,x:G.pl.x,z:G.pl.z,cities:CITIES.map(c=>c.f)}));}catch(e){}}
function loadSave(){try{return JSON.parse(localStorage.getItem(SKEY)||'null');}catch(e){return null;}}
function clearSave(){try{localStorage.removeItem(SKEY);}catch(e){}}
function clearWorld(){for(const u of U)removeUnitMesh(u);U=[];for(const p of PRJ){scene.remove(p.mesh);fxPool.push(p.mesh);}PRJ=[];if(G&&G.wrecks)for(const w of G.wrecks)scene.remove(w.mesh);if(G&&G.pl&&G.pl.mesh)scene.remove(G.pl.mesh);}
function parkTankNear(x,z,fac){const pt=rndLandNear(x,z,6,9);const v=mkUnit('tank',fac,pt.x,pt.z);v.empty=true;v.yaw=rand(0,TAU);U.push(v);
  const em=U.filter(u=>u.empty&&!u.dead);if(em.length>4){const o=em[0];o.dead=true;removeUnitMesh(o);}return v;}
function startGame(fac,sv){
  clearWorld();CITIES.forEach((c,i)=>{c.f=sv&&sv.cities&&FAC[sv.cities[i]]?sv.cities[i]:c.f0;c.prog=0;c.spawnCd=rand(0,3);drawCityFlag(c);});
  G={fac,side:FAC[fac].lado,money:sv?sv.money:300,kills:sv?sv.kills:0,score:sv?sv.score:0,missions:sv?sv.missions:0,changes:sv?sv.changes:0,up:sv?sv.up:{arm:0,gun:0,eng:0,mis:0},
    msgs:[],shake:0,t:0,saveT:15,mis:null,misCd:2,mapOpen:false,look:{yaw:0,pitch:0},wrecks:[],hurt:0,lastHurt:9,hitMark:0,recoil:0,bob:0,flashT:0};
  G.rpg=sv&&sv.rpg!==undefined?sv.rpg:rpgMax();
  let c=CBN[FAC[fac].start];if(sideOf(c)!==G.side)c=nearestCity(c.x,c.y,cc=>sideOf(cc)===G.side)||c;
  let sx=c.x+rand(-30,30),sz=c.y+rand(-30,30);if(sv&&sv.x&&groundH(sv.x,sv.z)>DEEP){sx=sv.x;sz=sv.z;}
  const pt=rndLandNear(sx,sz,0,30);G.pl=makePlayer(pt.x,pt.z);G.pl.mag=30;G.pl.reload=0;G.pl.rpgCd=0;U.push(G.pl);
  const ec=nearestCity(c.x,c.y,cc=>sideOf(cc)!==G.side);G.look.yaw=ec?yawTo(ec.x-c.x,ec.y-c.y):0;
  parkTankNear(G.pl.x,G.pl.z,fac);
  for(let i=0;i<3;i++)spawnAt(c,pick(['tank','apc','inf','inf']),fac);
  $('load').classList.add('on');
  setTimeout(()=>{updateChunks(G.pl.x,G.pl.z,true);$('load').classList.remove('on');state='play';last=0;
    addMsg(`${FAC[fac].n} — ${SIDE[G.side]}`,FAC[fac].cor);addMsg(sv?'Campanha retomada.':`Seu ${FAC[fac].tank} está estacionado ao lado — aperte ENTRAR`);save();},30);
  $('menu').classList.remove('on');clearTimeout(musicTimer);musicPlaying=false;if(musicG)musicG.gain.value=0;vm.visible=true;state='loading';}
function respawn(){$('dead').classList.remove('on');G.money=Math.floor(G.money*.8);const c=nearestCity(G.pl.x,G.pl.z,c=>sideOf(c)===G.side);if(!c){endGame(false);return;}
  const pt=rndLandNear(c.x,c.y,10,60);U=U.filter(u=>!u.isP);const np=makePlayer(pt.x,pt.z);np.mag=30;np.reload=0;np.rpgCd=0;U.push(np);G.pl=np;G.rpg=rpgMax();G.hurt=0;vm.visible=true;
  parkTankNear(np.x,np.z,G.fac);state='play';last=0;addMsg(`Reforços em ${c.n}. Há um ${FAC[G.fac].tank} ao seu lado.`);}
function openPause(){if(state!=='play')return;state='pause';input.reset();if(document.pointerLockElement)document.exitPointerLock();
  $('pStats').innerHTML=`${FAC[G.fac].n} · ${SIDE[G.side]}<br>Dinheiro $${G.money} · Abates ${G.kills} · Missões ${G.missions} · Pontos ${G.score}`;$('pause').classList.add('on');save();}
function resume(){$('pause').classList.remove('on');state='play';last=0;}
function openShop(){if(state!=='play')return;state='shop';input.reset();if(document.pointerLockElement)document.exitPointerLock();renderShop();$('shopOv').classList.add('on');}
function closeShop(){$('shopOv').classList.remove('on');state='play';last=0;}
function renderShop(){const p=G.pl,miss=Math.ceil(p.mhp-p.hp),rc=Math.ceil(miss*(p.veh?.3:1));$('shopMoney').textContent=`Dinheiro: $${G.money} · ${G.inCity?G.inCity.n:''}`;
  let h=`<div class="item"><b>${p.veh?'Reparar veículo':'Curativo'}</b><br>${miss>0?`Faltam ${miss} pontos`:'Tudo em ordem'}<br><div class="btn ${miss>0&&G.money>=rc?'':'dis'}" data-k="rep">$${rc}</div></div>`;
  h+=`<div class="item"><b>Foguetes ${FAC[G.fac].rpg}</b><br>${G.rpg}/${rpgMax()} foguetes<br><div class="btn ${G.rpg<rpgMax()&&G.money>=60?'':'dis'}" data-k="ammo">$60</div></div>`;
  h+=`<div class="item"><b>Requisitar ${FAC[G.fac].tank}</b><br>Um tanque novo estacionado ao seu lado<br><div class="btn ${G.money>=250?'':'dis'}" data-k="tank">$250</div></div>`;
  for(const [k,n,d,base] of UPG){const lv=G.up[k],cost=base*(lv+1);h+=`<div class="item"><b>${n}</b> (nível ${lv}/5)<br>${d}<br><div class="btn ${lv<5&&G.money>=cost?'':'dis'}" data-k="${k}">${lv<5?'$'+cost:'MÁXIMO'}</div></div>`;}
  const fr=CITIES.filter(c=>sideOf(c)===G.side&&c!==G.inCity).sort((a,b)=>Math.hypot(a.x-p.x,a.y-p.z)-Math.hypot(b.x-p.x,b.y-p.z));
  h+=`<div class="item" style="grid-column:1/-1"><b>Transporte rápido ($80)</b> — viaje para outra cidade aliada<br>${fr.map(c=>`<div class="btn ${G.money>=80?'':'dis'}" data-k="tp" data-c="${c.n}">${c.n}</div>`).join('')}</div>`;
  $('shopList').innerHTML=h;
  $('shopList').querySelectorAll('.btn').forEach(b=>b.onclick=()=>{const k=b.dataset.k;
    if(k==='rep'){G.money-=rc;p.hp=p.mhp;}
    else if(k==='ammo'){G.money-=60;G.rpg=rpgMax();}
    else if(k==='tank'){G.money-=250;parkTankNear(p.x,p.z,G.fac);addMsg('Tanque entregue ao seu lado!');}
    else if(k==='tp'){const c=CBN[b.dataset.c];G.money-=80;if(p.veh)exitVehicle();const pt=rndLandNear(c.x,c.y,10,60);p.x=pt.x;p.z=pt.z;for(const u of U)if(!u.isP&&!u.mission&&Math.hypot(u.x-p.x,u.z-p.z)>2000){u.dead=true;removeUnitMesh(u);}
      updateChunks(p.x,p.z,true);parkTankNear(p.x,p.z,G.fac);addMsg(`Chegou em ${c.n}`);save();closeShop();return;}
    else{const u=UPG.find(x=>x[0]===k);const cost=u[3]*(G.up[k]+1);if(G.money<cost||G.up[k]>=5)return;G.money-=cost;G.up[k]++;if(!p.veh){const r=p.hp/p.mhp;p.mhp=footMax();p.hp=Math.round(p.mhp*r);}}
    sfx('hit');save();renderShop();});}

/* ================= menu ================= */
function buildMenu(){const box=$('nations');box.innerHTML='';
  for(const k of FKEYS){const F=FAC[k];const d=document.createElement('div');d.className='nat';const c=document.createElement('canvas');c.width=168;c.height=104;drawFlag(c.getContext('2d'),k,0,0,168,104);d.appendChild(c);
    d.insertAdjacentHTML('beforeend',`<b>${F.n}</b><small>${F.desc}</small><small>${F.rifle} · ${F.tank} · ${F.heli}</small><span class="side ${F.lado==='PV'?'pv':'otan'}">${SIDE[F.lado]}</span>`);
    d.onclick=()=>{audioInit();clearSave();startGame(k,null);};box.appendChild(d);}
  const sv=loadSave();$('bCont').classList.toggle('dis',!sv);$('bCont').textContent=sv&&FAC[sv.fac]?`Continuar (${FAC[sv.fac].s})`:'Continuar campanha';}
$('bCont').onclick=()=>{const sv=loadSave();if(sv&&FAC[sv.fac]){audioInit();startGame(sv.fac,sv);}};
$('bSom').onclick=()=>{audioInit();setSound(!soundOn);if(soundOn&&state==='menu')playMusic();};
$('bGfx').onclick=()=>{gfxHigh=!gfxHigh;try{localStorage.setItem('gfma_gfx',gfxHigh?'1':'0');}catch(e){}applyGfx();};
$('pSom').onclick=()=>setSound(!soundOn);
$('pRes').onclick=resume;$('pMap').onclick=()=>{resume();G.mapOpen=true;};
$('pMenu').onclick=()=>{save();$('pause').classList.remove('on');toMenu();};
$('shopClose').onclick=closeShop;$('bRespawn').onclick=respawn;$('bEnd').onclick=()=>{$('endOv').classList.remove('on');toMenu();};
function toMenu(){state='menu';clearWorld();G=null;buildMenu();$('menu').classList.add('on');if(AC&&musicG){musicG.gain.value=.16;playMusic();}}
$('menu').addEventListener('pointerdown',()=>{audioInit();if(state==='menu'&&musicG){musicG.gain.value=.16;playMusic();}});

window.addEventListener('resize',()=>{resize();$('rot').classList.toggle('need',innerHeight>innerWidth);});
applyGfx();$('rot').classList.toggle('need',innerHeight>innerWidth);setSound(soundOn);
buildMini();buildMenu();requestAnimationFrame(step);
window.__gf={get G(){return G},get U(){return U},get PRJ(){return PRJ},CITIES,startGame,mkUnit,groundH,camera,renderer,get state(){return state}};
})();
