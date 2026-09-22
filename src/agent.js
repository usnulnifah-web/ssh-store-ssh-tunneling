import http from 'node:http';
import crypto from 'node:crypto';
import {promises as fs} from 'node:fs';
import {spawn} from 'node:child_process';
import path from 'node:path';
import os from 'node:os';

const PORT=Number(process.env.AGENT_PORT||8787);
const SECRET=process.env.AGENT_SHARED_SECRET;
const DATA_FILE=process.env.AGENT_DATA_FILE||'/var/lib/ssh-store-agent/accounts.json';
const MAX_SKEW_SECONDS=Number(process.env.AGENT_MAX_SKEW_SECONDS||60);
if(!SECRET){console.error('AGENT_SHARED_SECRET wajib diisi');process.exit(1)}

const json=(res,status,data)=>{res.writeHead(status,{'content-type':'application/json; charset=utf-8'});res.end(JSON.stringify(data))};
const readBody=req=>new Promise((resolve,reject)=>{let b='';req.on('data',c=>{b+=c;if(b.length>10000)reject(new Error('body too large'))});req.on('end',()=>{try{resolve(b?JSON.parse(b):{})}catch{reject(new Error('invalid json'))}});req.on('error',reject)});
const validUsername=u=>typeof u==='string'&&/^[a-z][a-z0-9_-]{2,31}$/.test(u);
const validDays=n=>Number.isInteger(n)&&n>=1&&n<=365;
const sign=(timestamp,body)=>crypto.createHmac('sha256',SECRET).update(`${timestamp}.${body}`).digest('hex');
const safeEqual=(a,b)=>{const x=Buffer.from(a||'');const y=Buffer.from(b||'');return x.length===y.length&&crypto.timingSafeEqual(x,y)};
function auth(req,raw){const ts=req.headers['x-agent-timestamp'];const sig=req.headers['x-agent-signature'];if(!ts||!sig||Math.abs(Math.floor(Date.now()/1000)-Number(ts))>MAX_SKEW_SECONDS)return false;return safeEqual(sign(ts,raw),sig)}
async function load(){try{return JSON.parse(await fs.readFile(DATA_FILE,'utf8'))}catch(e){if(e.code==='ENOENT')return {};throw e}}
async function save(data){await fs.mkdir(path.dirname(DATA_FILE),{recursive:true,mode:0o700});await fs.writeFile(DATA_FILE,JSON.stringify(data,null,2),{mode:0o600})}
function password(){return crypto.randomBytes(18).toString('base64url')}
function expiry(days){const d=new Date(Date.now()+days*86400000);return d.toISOString().slice(0,10)}
function command(file,args,input){return new Promise((resolve,reject)=>{const p=spawn(file,args,{stdio:['pipe','pipe','pipe']});let out='',err='';p.stdout.on('data',d=>out+=d);p.stderr.on('data',d=>err+=d);p.on('error',reject);p.on('close',code=>code===0?resolve(out.trim()):reject(new Error(err.trim()||`${file} exit ${code}`)));if(input){p.stdin.end(input)}else p.stdin.end()})}
async function createAccount({username,days}){if(!validUsername(username))throw new Error('username tidak valid');if(!validDays(days))throw new Error('days harus 1 sampai 365');const db=await load();if(db[username])throw new Error('username sudah ada');const pass=password(),expires=expiry(days);await command('/usr/sbin/useradd',['-m','-s','/usr/sbin/nologin',username]);try{await command('/usr/sbin/chpasswd',[],`${username}:${pass}\n`);await command('/usr/sbin/usermod',['-e',expires,username])}catch(e){await command('/usr/sbin/userdel',['-r',username]).catch(()=>{});throw e}db[username]={username,expires,createdAt:new Date().toISOString(),status:'active'};await save(db);return {username,password:pass,expires,status:'active'}}
async function extendAccount({username,days}){if(!validUsername(username)||!validDays(days))throw new Error('parameter tidak valid');const db=await load();if(!db[username])throw new Error('akun tidak ditemukan');const next=expiry(days);await command('/usr/sbin/usermod',['-e',next,username]);db[username].expires=next;db[username].status='active';await save(db);return db[username]}
async function setStatus(username,status){if(!validUsername(username)||!['active','suspended'].includes(status))throw new Error('parameter tidak valid');const db=await load();if(!db[username])throw new Error('akun tidak ditemukan');if(status==='suspended')await command('/usr/sbin/usermod',['-L',username]);else await command('/usr/sbin/usermod',['-U',username]);db[username].status=status;await save(db);return db[username]}
async function deleteAccount(username){if(!validUsername(username))throw new Error('username tidak valid');const db=await load();if(!db[username])throw new Error('akun tidak ditemukan');await command('/usr/sbin/userdel',['-r',username]);delete db[username];await save(db);return {deleted:true,username}}
function metrics(){const total=os.totalmem(),free=os.freemem(),cpu=Math.min(100,Math.round((os.loadavg()[0]/Math.max(1,os.cpus().length))*100));return {status:'online',hostname:os.hostname(),uptimeSeconds:Math.round(os.uptime()),cpuPercent:cpu,memoryPercent:Math.round(((total-free)/total)*100),loadAverage:os.loadavg(),checkedAt:new Date().toISOString()}}
const server=http.createServer(async(req,res)=>{try{if(req.method==='GET'&&req.url==='/health')return json(res,200,{ok:true,service:'ssh-store-agent'});const raw=await readBody(req).then(x=>JSON.stringify(x));if(!auth(req,raw))return json(res,401,{ok:false,error:'unauthorized'});const body=raw==='{}'?{}:JSON.parse(raw);if(req.method==='GET'&&req.url==='/metrics')return json(res,200,{ok:true,metrics:metrics()});if(req.method==='POST'&&req.url==='/accounts'){return json(res,201,{ok:true,account:await createAccount(body)})}if(req.method==='POST'&&req.url==='/accounts/extend'){return json(res,200,{ok:true,account:await extendAccount(body)})}if(req.method==='POST'&&req.url==='/accounts/status'){return json(res,200,{ok:true,account:await setStatus(body.username,body.status)})}if(req.method==='DELETE'&&req.url.startsWith('/accounts/')){return json(res,200,{ok:true,result:await deleteAccount(req.url.split('/').pop())})}return json(res,404,{ok:false,error:'not found'})}catch(e){console.error(e);return json(res,400,{ok:false,error:e.message})}});
server.listen(PORT,'127.0.0.1',()=>console.log(`SSH Store Agent listening on 127.0.0.1:${PORT}`));
