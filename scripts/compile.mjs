import fs from 'node:fs';
import solc from 'solc';
const sources = Object.fromEntries(['QuestEscrow.sol'].map(f => [f,{content:fs.readFileSync(`contracts/${f}`,'utf8')}]));
const output = JSON.parse(solc.compile(JSON.stringify({language:'Solidity',sources,settings:{evmVersion:'shanghai',optimizer:{enabled:true,runs:200},outputSelection:{'*':{'*':['abi','evm.bytecode.object']}}}})));
for (const e of output.errors || []) console.error(e.formattedMessage);
if ((output.errors || []).some(e => e.severity === 'error')) process.exit(1);
fs.mkdirSync('artifacts',{recursive:true});
fs.writeFileSync('artifacts/QuestEscrow.json',JSON.stringify(output.contracts['QuestEscrow.sol'].QuestEscrow,null,2));
