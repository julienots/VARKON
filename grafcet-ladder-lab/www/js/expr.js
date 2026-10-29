// Analyseur d'expressions booléennes (réceptivités GRAFCET).
// Syntaxe acceptée :
//   ET  : .  *  &  ET
//   OU  : +  |  OU
//   NON : /  !  NON   (ex : /S1  ou  NON S1)
//   Front montant : ↑S1  ou  ^S1      Front descendant : ↓S1  ou  vS1 n'est pas accepté, utiliser ↓
//   Temporisation : t/X2/3s   (vraie quand l'étape 2 est active depuis 3 s ; unités ms, s, min)
//   Constantes : 1 (toujours vrai) et 0
//   Variables : mnémoniques (dcy, S1...) ou adresses (%I2.0, %M5, X3...)
const Expr = (() => {
  class ExprError extends Error {
    constructor(msg, pos, help) { super(msg); this.pos = pos; this.help = help; }
  }

  function tokenize(src) {
    const toks = [];
    let i = 0;
    while (i < src.length) {
      const ch = src[i];
      if (/\s/.test(ch)) { i++; continue; }
      const rest = src.slice(i);
      let m;
      if ((m = /^t\s*\/\s*X(\d+)\s*\/\s*(\d+(?:[.,]\d+)?)\s*(ms|s|min)?/i.exec(rest))) {
        const val = parseFloat(m[2].replace(',', '.'));
        const unit = (m[3] || 's').toLowerCase();
        const ms = unit === 'ms' ? val : unit === 'min' ? val * 60000 : val * 1000;
        toks.push({ t: 'tempo', step: parseInt(m[1], 10), ms, pos: i, text: m[0] });
        i += m[0].length; continue;
      }
      if ((m = /^%[A-Za-z]+\d+(?:\.\d+)?/.exec(rest))) {
        toks.push({ t: 'id', v: m[0].toUpperCase(), pos: i }); i += m[0].length; continue;
      }
      if ((m = /^[A-Za-zÀ-ÿ_][A-Za-zÀ-ÿ0-9_]*/.exec(rest))) {
        const w = m[0];
        const up = w.toUpperCase();
        if (up === 'ET' || up === 'AND') toks.push({ t: 'and', pos: i });
        else if (up === 'OU' || up === 'OR') toks.push({ t: 'or', pos: i });
        else if (up === 'NON' || up === 'NOT') toks.push({ t: 'not', pos: i });
        else toks.push({ t: 'id', v: w, pos: i });
        i += w.length; continue;
      }
      if (ch === '0' || ch === '1') {
        if (/^[01](?![0-9])/.test(rest)) { toks.push({ t: 'const', v: ch === '1', pos: i }); i++; continue; }
      }
      if ('.*&·'.includes(ch)) { toks.push({ t: 'and', pos: i }); i++; continue; }
      if ('+|'.includes(ch)) { toks.push({ t: 'or', pos: i }); i++; continue; }
      if ('/!¬'.includes(ch)) { toks.push({ t: 'not', pos: i }); i++; continue; }
      if (ch === '↑' || ch === '^') { toks.push({ t: 're', pos: i }); i++; continue; }
      if (ch === '↓') { toks.push({ t: 'fe', pos: i }); i++; continue; }
      if (ch === '(') { toks.push({ t: '(', pos: i }); i++; continue; }
      if (ch === ')') { toks.push({ t: ')', pos: i }); i++; continue; }
      throw new ExprError(`Caractère « ${ch} » non reconnu (position ${i + 1}).`, i,
        'Utilise uniquement des noms de variables, les opérateurs . + / ↑ et les parenthèses.');
    }
    return toks;
  }

  function parse(src) {
    if (src == null || String(src).trim() === '') {
      throw new ExprError('La réceptivité est vide.', 0,
        'Une transition doit toujours avoir une réceptivité. Si elle doit être franchie immédiatement, écris 1.');
    }
    const toks = tokenize(String(src));
    let p = 0;
    const peek = () => toks[p];
    const eat = (t) => { if (toks[p] && toks[p].t === t) return toks[p++]; return null; };

    function parseOr() {
      let a = parseAnd();
      while (eat('or')) {
        if (!peek()) throw new ExprError('Il manque quelque chose après le « + » (OU).', src.length,
          'Après un OU il faut une variable. Ex : a + b');
        a = { op: 'or', a, b: parseAnd() };
      }
      return a;
    }
    function parseAnd() {
      let a = parseUnary();
      for (;;) {
        if (eat('and')) {
          if (!peek()) throw new ExprError('Il manque quelque chose après le « . » (ET).', src.length,
            'Après un ET il faut une variable. Ex : a . b');
          a = { op: 'and', a, b: parseUnary() };
        } else if (peek() && ['id', 'not', '(', 're', 'fe', 'tempo', 'const'].includes(peek().t)) {
          // deux variables côte à côte sans opérateur
          throw new ExprError(`Il manque un opérateur avant « ${tokText(peek())} ».`, peek().pos,
            'Entre deux variables il faut un opérateur : « . » pour ET, « + » pour OU.');
        } else break;
      }
      return a;
    }
    function parseUnary() {
      const tk = peek();
      if (!tk) throw new ExprError('Expression incomplète : il manque une variable à la fin.', src.length,
        'Vérifie que ton expression ne se termine pas par un opérateur.');
      if (eat('not')) return { op: 'not', a: parseUnary() };
      if (eat('re')) {
        const id = eat('id');
        if (!id) throw new ExprError('Le front montant ↑ doit être suivi d\'une variable.', tk.pos, 'Ex : ↑dcy');
        return { op: 're', name: id.v };
      }
      if (eat('fe')) {
        const id = eat('id');
        if (!id) throw new ExprError('Le front descendant ↓ doit être suivi d\'une variable.', tk.pos, 'Ex : ↓S1');
        return { op: 'fe', name: id.v };
      }
      if (eat('(')) {
        const e = parseOr();
        if (!eat(')')) throw new ExprError('Parenthèse fermante « ) » manquante.', src.length,
          'Chaque « ( » ouverte doit être refermée par une « ) ».');
        return e;
      }
      let t;
      if ((t = eat('id'))) return { op: 'var', name: t.v };
      if ((t = eat('tempo'))) return { op: 'tempo', step: t.step, ms: t.ms };
      if ((t = eat('const'))) return { op: 'const', v: t.v };
      if (tk.t === ')') throw new ExprError('Parenthèse fermante « ) » en trop ou mal placée.', tk.pos,
        'Compte tes parenthèses : il doit y avoir autant de « ( » que de « ) ».');
      throw new ExprError(`Opérateur « ${tokText(tk)} » mal placé.`, tk.pos,
        'Un opérateur ET/OU doit se trouver entre deux variables.');
    }
    const ast = parseOr();
    if (p < toks.length) {
      const tk = toks[p];
      if (tk.t === ')') throw new ExprError('Parenthèse fermante « ) » en trop.', tk.pos,
        'Compte tes parenthèses : il doit y avoir autant de « ( » que de « ) ».');
      throw new ExprError(`Je ne comprends pas la suite à partir de « ${tokText(tk)} ».`, tk.pos,
        'Vérifie qu\'il y a bien un opérateur entre chaque variable.');
    }
    return ast;
  }

  function tokText(tk) {
    return ({ and: '.', or: '+', not: '/', re: '↑', fe: '↓', '(': '(', ')': ')' })[tk.t]
      || tk.v || tk.text || '?';
  }

  // Liste des noms de variables utilisés
  function vars(ast, out = new Set()) {
    if (!ast) return out;
    if (ast.op === 'var' || ast.op === 're' || ast.op === 'fe') out.add(ast.name);
    if (ast.a) vars(ast.a, out);
    if (ast.b) vars(ast.b, out);
    return out;
  }
  function tempos(ast, out = []) {
    if (!ast) return out;
    if (ast.op === 'tempo') out.push({ step: ast.step, ms: ast.ms });
    if (ast.a) tempos(ast.a, out);
    if (ast.b) tempos(ast.b, out);
    return out;
  }

  // ctx : { get(name), edge(name, rising), tempo(step, ms) }
  function evaluate(ast, ctx) {
    switch (ast.op) {
      case 'and': return evaluate(ast.a, ctx) && evaluate(ast.b, ctx);
      case 'or': return evaluate(ast.a, ctx) || evaluate(ast.b, ctx);
      case 'not': return !evaluate(ast.a, ctx);
      case 'var': return !!ctx.get(ast.name);
      case 're': return !!ctx.edge(ast.name, true);
      case 'fe': return !!ctx.edge(ast.name, false);
      case 'tempo': return !!ctx.tempo(ast.step, ast.ms);
      case 'const': return ast.v;
    }
    return false;
  }

  // Forme disjonctive (somme de produits) : utile pour traduire en Ladder.
  // Chaque produit = liste de littéraux {kind, name|step/ms, neg}
  function toDNF(ast, neg = false) {
    const MAX = 32;
    if (ast.op === 'not') return toDNF(ast.a, !neg);
    if (ast.op === 'const') {
      const v = neg ? !ast.v : ast.v;
      return v ? [[]] : [];
    }
    if (ast.op === 'var' || ast.op === 're' || ast.op === 'fe') {
      return [[{ kind: ast.op, name: ast.name, neg }]];
    }
    if (ast.op === 'tempo') return [[{ kind: 'tempo', step: ast.step, ms: ast.ms, neg }]];
    let op = ast.op;
    if (neg) op = op === 'and' ? 'or' : 'and'; // De Morgan
    const A = toDNF(ast.a, neg), B = toDNF(ast.b, neg);
    if (op === 'or') return A.concat(B).slice(0, MAX);
    const res = [];
    for (const x of A) for (const y of B) {
      if (res.length >= MAX) break;
      res.push(x.concat(y));
    }
    return res;
  }

  function toString(ast) {
    switch (ast.op) {
      case 'and': return `${wrap(ast.a, 'and')} . ${wrap(ast.b, 'and')}`;
      case 'or': return `${toString(ast.a)} + ${toString(ast.b)}`;
      case 'not': return ast.a.op === 'var' ? `/${ast.a.name}` : `/(${toString(ast.a)})`;
      case 'var': return ast.name;
      case 're': return `↑${ast.name}`;
      case 'fe': return `↓${ast.name}`;
      case 'tempo': return `t/X${ast.step}/${ast.ms >= 1000 ? ast.ms / 1000 + 's' : ast.ms + 'ms'}`;
      case 'const': return ast.v ? '1' : '0';
    }
    return '?';
  }
  function wrap(a, parent) { return a.op === 'or' && parent === 'and' ? `(${toString(a)})` : toString(a); }

  return { parse, evaluate, vars, tempos, toDNF, toString, ExprError };
})();
