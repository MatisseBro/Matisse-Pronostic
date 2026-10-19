import React from 'react';
import {
  AbsoluteFill,
  Audio,
  Easing,
  interpolate,
  OffthreadVideo,
  Sequence,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';

// ── Palette ───────────────────────────────────────────────────────────────────
const C = {
  dark:     '#09120B',
  primary:  '#1B5E20',
  accent:   '#4ADE80',
  white:    '#FFFFFF',
  dim:      'rgba(255,255,255,0.52)',
  accentBg: 'rgba(74,222,128,0.13)',
  accentBd: 'rgba(74,222,128,0.28)',
};
const F = "system-ui,-apple-system,'Segoe UI',sans-serif";

// ── Layout constants ──────────────────────────────────────────────────────────
// Composition: 1080 × 1920
const PW = 500;                // phone width
const PH = 1075;               // phone height
const PX = (1080 - PW) / 2;   // 290 — phone left (centré)
const PY = 560;                // phone top — bas (560 → 1635)
const SW = 476;                // screen width  (PW − 12 × 2)
const SH = 1055;               // screen height (PH − 10 × 2)
const VH = Math.round(SW * 1920 / 864); // 1057 — vidéo scalée
const PHONE_BOTTOM = PY + PH;  // 1635
// ─ Zone texte DESSUS   : 0 → 560   (560 px)
// ─ iPhone              : 560 → 1635 (1075 px)
// ─ Zone info DESSOUS   : 1635 → 1920 (285 px)

// ── Helpers ───────────────────────────────────────────────────────────────────
const fi = (
  f: number,
  [a, b]: [number, number],
  [c, d]: [number, number],
  easing?: (t: number) => number,
) => interpolate(f, [a, b], [c, d], {extrapolateLeft:'clamp', extrapolateRight:'clamp', easing});

const fadeIO = (f: number, inF: number, outF: number, dur = 15) =>
  interpolate(f, [inF, inF + dur, outF - dur, outF], [0, 1, 1, 0],
    {extrapolateLeft:'clamp', extrapolateRight:'clamp'});

// ── Particles ─────────────────────────────────────────────────────────────────
const Particles: React.FC<{n?: number; op?: number}> = ({n = 16, op = 1}) => {
  const f = useCurrentFrame();
  return (
    <div style={{position:'absolute', inset:0, overflow:'hidden', pointerEvents:'none'}}>
      {Array.from({length: n}).map((_, i) => {
        const x   = (i * 139.5 + 9) % 100;
        const spd = 0.09 + (i % 5) * 0.03;
        const y   = ((f * spd + i * 135) % 118) - 8;
        const sz  = 2 + (i % 3);
        const a   = (0.055 + (i % 5) * 0.024) * op;
        return <div key={i} style={{position:'absolute', left:`${x}%`, top:`${y}%`, width:sz, height:sz, borderRadius:'50%', background:C.accent, opacity:a}}/>;
      })}
    </div>
  );
};

// ── Kinetic word ─────────────────────────────────────────────────────────────
const W: React.FC<{text:string; at:number; color?:string; size?:number}> = ({
  text, at, color = C.white, size = 84,
}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const s  = spring({frame:Math.max(0,f-at), fps, config:{stiffness:230,damping:17,mass:0.82}});
  const sc = fi(s,[0,1],[1.38,1]);
  const ty = fi(s,[0,1],[28,0]);
  const op = fi(f,[at,at+10],[0,1]);
  return (
    <span style={{
      display:'inline-block', fontFamily:F, fontWeight:900,
      fontSize:size, color, letterSpacing:-2, lineHeight:1.0,
      transform:`scale(${sc}) translateY(${ty}px)`,
      transformOrigin:'center bottom', opacity:op,
    }}>{text}</span>
  );
};

// ── Animated underline ────────────────────────────────────────────────────────
const Line: React.FC<{at:number; w?:number}> = ({at, w = 60}) => {
  const f = useCurrentFrame();
  const pct = fi(f,[at,at+26],[0,w],Easing.out(Easing.cubic));
  return <div style={{width:`${pct}%`, height:4, background:`linear-gradient(90deg,${C.accent},${C.accent}55)`, borderRadius:2, marginTop:10}}/>;
};

// ── Category pill ─────────────────────────────────────────────────────────────
const Pill: React.FC<{text:string; at:number}> = ({text, at}) => {
  const f = useCurrentFrame();
  const op = fi(f,[at,at+18],[0,1]);
  const ty = fi(f,[at,at+18],[-8,0],Easing.out(Easing.quad));
  return (
    <span style={{
      fontFamily:F, fontWeight:700, fontSize:17, letterSpacing:3.5,
      color:C.accent, textTransform:'uppercase',
      background:C.accentBg, border:`1px solid ${C.accentBd}`,
      borderRadius:24, padding:'6px 20px',
      opacity:op, transform:`translateY(${ty}px)`, display:'inline-block',
    }}>{text}</span>
  );
};

// ── Subtitle line ─────────────────────────────────────────────────────────────
const Sub: React.FC<{text:string; at:number}> = ({text, at}) => {
  const f = useCurrentFrame();
  const op = fi(f,[at,at+20],[0,1]);
  const ty = fi(f,[at,at+20],[10,0],Easing.out(Easing.quad));
  return (
    <div style={{
      fontFamily:F, fontWeight:400, fontSize:24, color:C.dim,
      letterSpacing:0.5, textAlign:'center',
      opacity:op, transform:`translateY(${ty}px)`,
    }}>{text}</div>
  );
};

// ── Ambient glow behind phone ─────────────────────────────────────────────────
const BgGlow: React.FC<{frame:number}> = ({frame}) => {
  const breathe = 0.58 + 0.42 * Math.sin((frame / 52) * Math.PI);
  return (
    <>
      <div style={{
        position:'absolute', left:100, top:280, width:880, height:1400,
        background:`radial-gradient(ellipse at 50% 46%, ${C.primary}38,transparent 58%)`,
        opacity:breathe * 0.88, pointerEvents:'none',
      }}/>
      <div style={{
        position:'absolute', bottom:0, left:0, right:0, height:300,
        background:`linear-gradient(transparent,rgba(27,94,32,0.07))`,
        pointerEvents:'none',
      }}/>
    </>
  );
};

// ── iPhone mockup ─────────────────────────────────────────────────────────────
interface IPhoneProps {
  src: string;
  enterAt?: number;
}

const IPhone: React.FC<IPhoneProps> = ({src, enterAt = 0}) => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  // Plus de rebond sur l'entrée : stiffness élevée, damping faible
  const s   = spring({frame:Math.max(0,f-enterAt), fps, config:{stiffness:120,damping:14,mass:0.9}});
  const ty  = fi(s,[0,1],[150,0]);
  const ry  = fi(s,[0,1],[-5,0]);
  const sc  = fi(s,[0,1],[0.88,1.0]);
  const op  = fi(f,[enterAt,enterAt+16],[0,1]);
  const vmt = Math.round((SH - VH) / 2); // centre la vidéo verticalement

  return (
    <div style={{
      position:'absolute', left:PX, top:PY, width:PW, height:PH,
      transform:`perspective(1600px) rotateY(${ry}deg) translateY(${ty}px) scale(${sc})`,
      transformOrigin:'center bottom', opacity:op,
    }}>
      {/* Coque */}
      <div style={{
        width:PW, height:PH, borderRadius:52,
        background:'linear-gradient(158deg,#303030 0%,#1A1A1A 55%,#222 100%)',
        boxShadow:`
          inset 0 0 0 1px rgba(255,255,255,0.13),
          inset 0 0 0 2.5px rgba(0,0,0,0.55),
          0 70px 190px rgba(0,0,0,0.96),
          0 16px 55px rgba(0,0,0,0.72)
        `,
        position:'relative',
      }}>
        {/* Écran */}
        <div style={{
          position:'absolute', left:12, top:10, width:SW, height:SH,
          borderRadius:42, overflow:'hidden', background:'#000',
        }}>
          <OffthreadVideo
            src={src}
            style={{width:SW, height:VH, display:'block', marginTop:vmt}}
            muted
          />
          {/* Dynamic Island */}
          <div style={{position:'absolute',top:13,left:'50%',transform:'translateX(-50%)',width:118,height:32,background:'#000',borderRadius:16,zIndex:10}}/>
          {/* Home indicator */}
          <div style={{position:'absolute',bottom:9,left:'50%',transform:'translateX(-50%)',width:128,height:5,background:'rgba(255,255,255,0.22)',borderRadius:3,zIndex:10}}/>
          {/* Reflet verre */}
          <div style={{position:'absolute',inset:0,borderRadius:42,background:'linear-gradient(148deg,rgba(255,255,255,0.055) 0%,transparent 42%)',pointerEvents:'none',zIndex:11}}/>
        </div>

        {/* Boutons volume (gauche) */}
        <div style={{position:'absolute',left:-4,top:168,width:4,height:30,background:'#222',borderRadius:'2px 0 0 2px',boxShadow:'inset -1px 0 0 rgba(255,255,255,0.07)'}}/>
        <div style={{position:'absolute',left:-4,top:214,width:4,height:68,background:'#222',borderRadius:'2px 0 0 2px',boxShadow:'inset -1px 0 0 rgba(255,255,255,0.07)'}}/>
        <div style={{position:'absolute',left:-4,top:298,width:4,height:68,background:'#222',borderRadius:'2px 0 0 2px',boxShadow:'inset -1px 0 0 rgba(255,255,255,0.07)'}}/>
        {/* Bouton power (droite) */}
        <div style={{position:'absolute',right:-4,top:242,width:4,height:112,background:'#222',borderRadius:'0 2px 2px 0',boxShadow:'inset 1px 0 0 rgba(255,255,255,0.07)'}}/>
        {/* Ligne bord bas */}
        <div style={{position:'absolute',bottom:0,left:18,right:18,height:1,background:'rgba(255,255,255,0.055)',borderRadius:'0 0 52px 52px'}}/>
      </div>
    </div>
  );
};

// ── Bloc texte AU-DESSUS du téléphone ────────────────────────────────────────
// Zone : y = 0 → PY (430 px)
const TextTop: React.FC<{at:number; outAt:number; children:React.ReactNode}> = ({at,outAt,children}) => {
  const f = useCurrentFrame();
  const op = fadeIO(f, at, outAt, 15);
  return (
    <div style={{
      position:'absolute', top:0, left:0, right:0, height:PY,
      display:'flex', flexDirection:'column',
      alignItems:'center', justifyContent:'center',
      padding:'0 64px', gap:8,
      opacity:op,
    }}>
      {children}
    </div>
  );
};

// ── Bloc info EN-DESSOUS du téléphone ─────────────────────────────────────────
// Zone : y = PHONE_BOTTOM → 1920 (415 px)
const TextBottom: React.FC<{at:number; children:React.ReactNode}> = ({at,children}) => {
  const f = useCurrentFrame();
  const op = fi(f,[at,at+25],[0,1]);
  return (
    <div style={{
      position:'absolute', top:PHONE_BOTTOM+18, left:0, right:0, bottom:0,
      display:'flex', flexDirection:'column',
      alignItems:'center', justifyContent:'center',
      padding:'0 56px', gap:10,
      opacity:op,
    }}>
      {children}
    </div>
  );
};

// =============================================================================
// SCÈNE 1 — HOOK  plein-écran  (Seq 0 dur=135)
// =============================================================================
const S1Hook: React.FC = () => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const bgOp    = interpolate(f,[0,14,118,135],[0,1,1,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
  const glowOp  = fi(f,[50,102],[0,1]);
  const tagOp   = fi(f,[70,96],[0,1]);
  const tagY    = fi(f,[70,96],[14,0],Easing.out(Easing.quad));
  const lineW   = fi(f,[88,126],[0,148],Easing.out(Easing.cubic));
  const ballSc  = spring({frame:f, fps, config:{stiffness:140,damping:14}});

  const LETTERS = [
    {l:'M',c:C.white},{l:'A',c:C.white},{l:'T',c:C.white},{l:'I',c:C.white},
    {l:'M',c:C.accent},{l:'A',c:C.accent},{l:'T',c:C.accent},{l:'C',c:C.accent},{l:'H',c:C.accent},
  ];
  return (
    <AbsoluteFill style={{backgroundColor:C.dark, opacity:bgOp, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center'}}>
      <Particles n={18} op={0.7}/>
      <div style={{position:'absolute',width:760,height:760,borderRadius:'50%',background:`radial-gradient(circle,${C.primary}52,transparent 65%)`,opacity:glowOp}}/>
      <div style={{fontSize:100, marginBottom:26, transform:`scale(${fi(ballSc,[0,1],[0,1])})`, opacity:fi(f,[0,20],[0,1])}}>⚽</div>
      <div style={{display:'flex'}}>
        {LETTERS.map(({l,c},i) => {
          const s = spring({frame:Math.max(0,f-10-i*5),fps,config:{stiffness:268,damping:18,mass:0.72}});
          return <span key={i} style={{fontFamily:F,fontWeight:900,fontSize:106,color:c,letterSpacing:-3,display:'inline-block',transform:`translateY(${fi(s,[0,1],[46,0])}px) scale(${fi(s,[0,1],[0,1])})`,opacity:fi(f,[10+i*5,18+i*5],[0,1])}}>{l}</span>;
        })}
      </div>
      <div style={{fontFamily:F,fontWeight:500,fontSize:24,color:C.dim,letterSpacing:5,marginTop:16,textTransform:'uppercase',opacity:tagOp,transform:`translateY(${tagY}px)`}}>
        Pronostics · IoT · Connecté
      </div>
      <div style={{width:lineW,height:2,background:`linear-gradient(90deg,transparent,${C.accent},transparent)`,marginTop:20}}/>
    </AbsoluteFill>
  );
};

// =============================================================================
// SCÈNE 2 — LOGIN  (Seq 120 dur=195)
// =============================================================================
const S2Login: React.FC = () => {
  const f = useCurrentFrame();
  const op = fadeIO(f, 0, 195);
  return (
    <AbsoluteFill style={{backgroundColor:C.dark, opacity:op}}>
      <BgGlow frame={f}/>
      <IPhone src={staticFile('clips/c1_login.mp4')} enterAt={6}/>

      <TextTop at={14} outAt={178}>
        <Pill text="Connexion" at={14}/>
        <div style={{display:'flex',gap:10,flexWrap:'wrap',justifyContent:'center',alignItems:'baseline',marginTop:6}}>
          <W text="ACCÈDE" at={26} size={100}/>
          <W text="À TON" at={34} size={100}/>
        </div>
        <W text="COMPTE." at={42} color={C.accent} size={100}/>
        <Line at={54}/>
        <Sub text="Authentification Firebase sécurisée" at={58}/>
      </TextTop>

      <TextBottom at={50}>
        <Sub text="Google · Email · Compte sécurisé" at={50}/>
      </TextBottom>
    </AbsoluteFill>
  );
};

// =============================================================================
// SCÈNE 3 — MATCHS  (Seq 300 dur=390)
// =============================================================================
const S3Matches: React.FC = () => {
  const f = useCurrentFrame();
  const op = fadeIO(f, 0, 390);

  const b1Op = interpolate(f,[14,30,185,208],[0,1,1,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
  const b2Op = interpolate(f,[212,230,368,390],[0,1,1,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});

  return (
    <AbsoluteFill style={{backgroundColor:C.dark, opacity:op}}>
      <BgGlow frame={f}/>
      <IPhone src={staticFile('clips/c2_matches.mp4')} enterAt={8}/>

      {/* Beat 1 — découverte matchs */}
      <div style={{position:'absolute',top:0,left:0,right:0,height:PY,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',padding:'0 64px',gap:8,opacity:b1Op}}>
        <Pill text="Matchs en direct" at={14}/>
        <W text="RETROUVE" at={18} size={96}/>
        <W text="TOUS LES MATCHS" at={26} color={C.accent} size={84}/>
        <Sub text="Calendrier, côtes et résultats en temps réel" at={38}/>
        <Line at={50} w={65}/>
      </div>

      {/* Beat 2 — côtes live */}
      <div style={{position:'absolute',top:0,left:0,right:0,height:PY,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',padding:'0 64px',gap:8,opacity:b2Op}}>
        <Pill text="Côtes live" at={214}/>
        <W text="CÔTES &" at={220} size={100}/>
        <W text="INFOS EN DIRECT." at={230} color={C.accent} size={82}/>
        <Line at={244} w={70}/>
      </div>

      {/* Ligues en dessous */}
      <TextBottom at={55}>
        <div style={{display:'flex',flexWrap:'wrap',justifyContent:'center',gap:10}}>
          {['🇫🇷 Ligue 1','🏴󠁧󠁢󠁥󠁮󠁧󠁿 Premier L.','🇪🇸 La Liga','🇮🇹 Serie A'].map(t => (
            <span key={t} style={{fontFamily:F,fontWeight:700,fontSize:21,color:C.accent,background:C.accentBg,border:`1px solid ${C.accentBd}`,borderRadius:24,padding:'6px 16px'}}>{t}</span>
          ))}
        </div>
      </TextBottom>
    </AbsoluteFill>
  );
};

// =============================================================================
// SCÈNE 4 — DÉTAIL + ESP32  (Seq 675 dur=330)
// =============================================================================
const S4Detail: React.FC = () => {
  const f = useCurrentFrame();
  const op = fadeIO(f, 0, 330);
  // Point lumineux pulsant (pas de zoom pour éviter les problèmes de cadrage)
  const dot = 0.5 + 0.5 * Math.sin((f / 10) * Math.PI * 2);

  const b1Op = interpolate(f,[14,30,82,102],[0,1,1,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
  const b2Op = interpolate(f,[108,128,298,318],[0,1,1,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
  const mqOp = fi(f,[168,196],[0,1]);

  return (
    <AbsoluteFill style={{backgroundColor:C.dark, opacity:op}}>
      <BgGlow frame={f}/>
      <IPhone src={staticFile('clips/c3_detail.mp4')} enterAt={8}/>

      {/* Beat 1 — sélection du match */}
      <div style={{position:'absolute',top:0,left:0,right:0,height:PY,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',padding:'0 64px',gap:8,opacity:b1Op}}>
        <Pill text="Détail du match" at={14}/>
        <W text="SÉLECTIONNE" at={18} size={96}/>
        <W text="UN MATCH." at={28} color={C.accent} size={96}/>
        <Sub text="Stats, compositions, enjeux du match" at={40}/>
        <Line at={52} w={60}/>
      </div>

      {/* Beat 2 — révélation ESP32 / OLED */}
      <div style={{position:'absolute',top:0,left:0,right:0,height:PY,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',padding:'0 64px',gap:8,opacity:b2Op}}>
        <Pill text="Afficheur connecté" at={110}/>
        <W text="LE RÉSULTAT" at={116} size={96}/>
        <W text="SUR UN MINI-ÉCRAN." at={126} color={C.accent} size={80}/>
        <Sub text="L'ESP32 reçoit le score et l'affiche en temps réel" at={136}/>
        <Line at={148} w={66}/>
        {/* Indicateur MQTT live */}
        <div style={{display:'flex',alignItems:'center',gap:10,marginTop:10,opacity:mqOp}}>
          <div style={{width:10,height:10,borderRadius:'50%',background:C.accent,opacity:dot,boxShadow:`0 0 10px ${C.accent}`}}/>
          <span style={{fontFamily:F,fontWeight:600,fontSize:20,color:C.dim,letterSpacing:2.5}}>MQTT · TEMPS RÉEL</span>
          <div style={{width:10,height:10,borderRadius:'50%',background:C.accent,opacity:dot,boxShadow:`0 0 10px ${C.accent}`}}/>
        </div>
      </div>

      <TextBottom at={125}>
        <Sub text="L'afficheur OLED se met à jour automatiquement" at={125}/>
        <div style={{display:'flex',gap:10,marginTop:6}}>
          {['MQTT TLS','HiveMQ','ESP32','OLED SH1107'].map(t => (
            <span key={t} style={{fontFamily:F,fontWeight:700,fontSize:18,color:C.accent,background:C.accentBg,border:`1px solid ${C.accentBd}`,borderRadius:20,padding:'5px 14px'}}>{t}</span>
          ))}
        </div>
      </TextBottom>
    </AbsoluteFill>
  );
};

// =============================================================================
// SCÈNE 5 — PRONOSTIC  (Seq 990 dur=390)
// =============================================================================
const S5Prediction: React.FC = () => {
  const f = useCurrentFrame();
  const op = fadeIO(f, 0, 390);
  const b1Op = interpolate(f,[14,30,185,208],[0,1,1,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
  const b2Op = interpolate(f,[212,230,368,390],[0,1,1,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});

  return (
    <AbsoluteFill style={{backgroundColor:C.dark, opacity:op}}>
      <BgGlow frame={f}/>
      <IPhone src={staticFile('clips/c4_prediction.mp4')} enterAt={8}/>

      {/* Beat 1 — faire un pronostic */}
      <div style={{position:'absolute',top:0,left:0,right:0,height:PY,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',padding:'0 64px',gap:8,opacity:b1Op}}>
        <Pill text="Ton pronostic" at={14}/>
        <W text="PRONOSTIQUE" at={18} size={92}/>
        <W text="LE RÉSULTAT." at={28} color={C.accent} size={84}/>
        <Sub text="Score, buteur, cote personnalisée" at={40}/>
        <Line at={52} w={65}/>
      </div>

      {/* Beat 2 — suivi social */}
      <div style={{position:'absolute',top:0,left:0,right:0,height:PY,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',padding:'0 64px',gap:8,opacity:b2Op}}>
        <Pill text="Social" at={214}/>
        <W text="SUIS LES PRONOS" at={218} size={88}/>
        <W text="DE TES AMIS." at={228} color={C.accent} size={96}/>
        <Sub text="Tes amis partagent leurs pronostics, tu les vois en direct" at={240}/>
        <Line at={252} w={70}/>
      </div>

      <TextBottom at={55}>
        <Sub text="Partage tes pronostics directement depuis l'app" at={55}/>
      </TextBottom>
    </AbsoluteFill>
  );
};

// =============================================================================
// SCÈNE 6 — PROFIL  (Seq 1365 dur=255)
// =============================================================================
const S6Profile: React.FC = () => {
  const f = useCurrentFrame();
  const op = fadeIO(f, 0, 255);
  const b1Op = interpolate(f,[14,30,110,130],[0,1,1,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
  const b2Op = interpolate(f,[134,152,228,248],[0,1,1,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});

  return (
    <AbsoluteFill style={{backgroundColor:C.dark, opacity:op}}>
      <BgGlow frame={f}/>
      <IPhone src={staticFile('clips/c5_profile.mp4')} enterAt={8}/>

      {/* Beat 1 */}
      <div style={{position:'absolute',top:0,left:0,right:0,height:PY,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',padding:'0 64px',gap:8,opacity:b1Op}}>
        <Pill text="Profil & Stats" at={14}/>
        <W text="TES STATS," at={18} size={100}/>
        <W text="TES VICTOIRES." at={28} color={C.accent} size={84}/>
        <Line at={42} w={58}/>
      </div>

      {/* Beat 2 */}
      <div style={{position:'absolute',top:0,left:0,right:0,height:PY,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',padding:'0 64px',gap:8,opacity:b2Op}}>
        <Pill text="Classement amis" at={136}/>
        <W text="COMPARE-TOI" at={142} size={92}/>
        <W text="À TES AMIS." at={152} color={C.accent} size={92}/>
        <Line at={166} w={52}/>
      </div>

      <TextBottom at={55}>
        <Sub text="Classement en temps réel entre amis" at={55}/>
      </TextBottom>
    </AbsoluteFill>
  );
};

// =============================================================================
// SCÈNE 7 — OUTRO  plein-écran  (Seq 1605 dur=195)
// =============================================================================
const S7Outro: React.FC = () => {
  const f = useCurrentFrame();
  const {fps} = useVideoConfig();
  const bgOp   = fi(f,[0,18],[0,1]);
  const glowOp = fi(f,[18,65],[0,1]);
  const ballS  = spring({frame:Math.max(0,f-14),fps,config:{stiffness:160,damping:14}});
  const pulse  = 1 + 0.026 * Math.sin((f/18)*Math.PI*2);
  const titS   = spring({frame:Math.max(0,f-38),fps,config:{stiffness:200,damping:16}});
  const titSc  = fi(titS,[0,1],[0.55,1]);
  const titOp  = fi(f,[38,58],[0,1]);
  const lineW  = fi(f,[82,118],[0,150],Easing.out(Easing.cubic));
  const lineOp = fi(f,[82,110],[0,1]);
  const t1Op   = fi(f,[105,130],[0,1]);
  const t1Y    = fi(f,[105,130],[18,0],Easing.out(Easing.quad));
  const t2Op   = fi(f,[140,168],[0,1]);
  const t2Y    = fi(f,[140,168],[14,0],Easing.out(Easing.quad));
  const ctaOp  = fi(f,[155,178],[0,1]);
  return (
    <AbsoluteFill style={{backgroundColor:C.dark, opacity:bgOp, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center'}}>
      <Particles n={22} op={0.9}/>
      <div style={{position:'absolute',width:960,height:960,borderRadius:'50%',background:`radial-gradient(circle,${C.primary}50,transparent 64%)`,opacity:glowOp}}/>
      <div style={{fontSize:98,transform:`scale(${fi(ballS,[0,1],[0,1])*pulse})`,opacity:fi(f,[14,34],[0,1]),marginBottom:22}}>⚽</div>
      <div style={{fontFamily:F,fontWeight:900,fontSize:112,letterSpacing:-4,lineHeight:1,opacity:titOp,transform:`scale(${titSc})`}}>
        <span style={{color:C.white}}>MATI</span><span style={{color:C.accent}}>MATCH</span>
      </div>
      <div style={{width:lineW,height:3,background:`linear-gradient(90deg,transparent,${C.accent},transparent)`,borderRadius:2,margin:'24px auto',opacity:lineOp}}/>
      <div style={{fontFamily:F,fontWeight:700,fontSize:30,color:'rgba(255,255,255,0.86)',textAlign:'center',padding:'0 80px',opacity:t1Op,transform:`translateY(${t1Y}px)`,letterSpacing:0.5}}>
        Joue. Pronostique. Connecte.
      </div>
      <div style={{fontFamily:F,fontWeight:400,fontSize:20,color:'rgba(74,222,128,0.55)',textAlign:'center',marginTop:14,letterSpacing:3,textTransform:'uppercase',opacity:t2Op,transform:`translateY(${t2Y}px)`}}>
        Flutter · Firebase · MQTT · ESP32
      </div>
      <div style={{fontFamily:F,fontWeight:600,fontSize:18,color:C.accent,textAlign:'center',marginTop:28,letterSpacing:1,opacity:ctaOp,border:`1px solid ${C.accentBd}`,borderRadius:30,padding:'12px 36px',background:C.accentBg}}>
        Application mobile — Soutenance 2025
      </div>
    </AbsoluteFill>
  );
};

// =============================================================================
// ROOT
// =============================================================================

// Transitions : flash vert + ligne de balayage à chaque changement de scène
const TRANS = [120, 300, 675, 990, 1365, 1605];

const TransitionFX: React.FC = () => {
  const f = useCurrentFrame();

  let flashOp = 0;
  let sweepY  = -10;
  let sweepOp = 0;

  for (const t of TRANS) {
    const lf = f - t;
    if (lf >= 0 && lf < 16) {
      flashOp = Math.max(flashOp,
        interpolate(lf, [0, 1, 10, 16], [0, 0.45, 0.45, 0],
          {extrapolateLeft:'clamp', extrapolateRight:'clamp'}));
      sweepY  = interpolate(lf, [0, 16], [-4, 108],
        {extrapolateLeft:'clamp', extrapolateRight:'clamp',
         easing: Easing.out(Easing.quad)});
      sweepOp = interpolate(lf, [0, 2, 13, 16], [0, 1, 1, 0],
        {extrapolateLeft:'clamp', extrapolateRight:'clamp'});
    }
  }

  return (
    <>
      {/* Flash vert */}
      <div style={{
        position:'absolute', inset:0, pointerEvents:'none', zIndex:200,
        background: `linear-gradient(180deg, ${C.accent}00, ${C.primary}55, ${C.accent}00)`,
        opacity: flashOp,
      }}/>
      {/* Ligne de balayage */}
      <div style={{
        position:'absolute', left:0, right:0, top:`${sweepY}%`,
        height:3, pointerEvents:'none', zIndex:201,
        background:`linear-gradient(90deg,transparent 0%,${C.accent} 30%,#fff 50%,${C.accent} 70%,transparent 100%)`,
        opacity: sweepOp,
        filter:'blur(0.5px)',
        boxShadow:`0 0 18px ${C.accent}, 0 0 6px #fff`,
      }}/>
    </>
  );
};

export const MatiMatchAd: React.FC = () => {
  const f   = useCurrentFrame();
  const vol = interpolate(f,[1740,1800],[0.50,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
  return (
    <AbsoluteFill style={{backgroundColor:C.dark}}>
      <Audio src={staticFile('music.mp3')} volume={vol}/>
      <Sequence from={0}    durationInFrames={135} layout="none"><S1Hook/></Sequence>
      <Sequence from={120}  durationInFrames={195} layout="none"><S2Login/></Sequence>
      <Sequence from={300}  durationInFrames={390} layout="none"><S3Matches/></Sequence>
      <Sequence from={675}  durationInFrames={330} layout="none"><S4Detail/></Sequence>
      <Sequence from={990}  durationInFrames={390} layout="none"><S5Prediction/></Sequence>
      <Sequence from={1365} durationInFrames={255} layout="none"><S6Profile/></Sequence>
      <Sequence from={1605} durationInFrames={195} layout="none"><S7Outro/></Sequence>
      {/* Effets de transition par-dessus tout */}
      <TransitionFX/>
    </AbsoluteFill>
  );
};
