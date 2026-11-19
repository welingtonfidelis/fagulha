# Relatório do designer sênior (level design, estrutura e usabilidade)

Data: 2026-11-19. Base: `main` como estava no disco (README, `docs/JOGO-VOO.md` até a §98, `scripts/`), dados do relevo em `assets/vale/mapa/` e fotos tiradas agora em `tools/capturas/design_dia`, `design_noite`, `design_menus`, `design_hud` e `design_leste`.

Cada achado leva uma marca: **[foto]** (visto em foto), **[código]** (lido no código) ou **[dedução]** (conta ou raciocínio meu, sem ter jogado). Não joguei com controle; não tirei nenhuma conclusão de fps.

## Resumo em 5 linhas

1. A ilha é bonita e se lê bem do alto: voando a 40 m, quase todo ponto de terra enxerga 8 ou mais marcos altos. No chão, perto de 30% da terra não enxerga nenhum, e a faixa oeste e o sul do meio ficam a 600–700 m de qualquer lugar com nome.
2. Não há barreira nenhuma. Desde o primeiro minuto o robô voa 1 km, esfria em 7 s no chão e chega a qualquer lugar da ilha em menos de 2 minutos de voo. Nenhuma das 10 peças abre um lugar novo: todas só mexem num número.
3. A curva das peças está torta. O radiador duplo, que devia ser o prêmio "de longe", fica a 588 m da base e a 31 m do chão, e acaba com o calor nos primeiros 10 minutos. Os bocais, o prêmio mais distante (1,9 km), dão só 6 m/s de arrancada.
4. O laço "cozy" é curto: chegar, ver o nome, tocar e ir embora. Há uns 20 prêmios para umas 2 horas, não há fim e não há nada que chame o jogador de volta. Já o laço de luta (Fundição, 6 modos de tiro, níveis, materiais, chefes) é bem mais fundo, e a bússola aponta para ele desde o começo com uma caveira.
5. A criança que não lê fica de fora do que o jogo tem de mais "dele": as memórias, as fichas do scanner, a oficina, a tabela de comandos e os avisos são só texto. E não há nenhum ensino dos 22 comandos dentro do jogo.

## 1. O mapa

### 1.1 Números de base [código]

| Coisa | Valor | De onde |
|---|---|---|
| Terra | ~5,5 km², de x −1.300 a +1.400 e z −1.400 a +1.250 (norte = z negativo) | `alturas.bin`, 751×751, 4 m |
| Ponto mais alto | Cume da Serra do Mirante, 284 m, em (−564, −628) | conta no `alturas.bin` |
| Altura média da terra | 41 m | idem |
| Base (nascimento) | (2, 44), chão a 26 m | `Clareira.spawn`, `Ruinas.BASE` |
| Andar / correr | 2,1 / 6,3 m/s | `Ajustes.ANDAR` e `CORRER` × `Armadura.vel_chao` 0,7 |
| Voo de cruzeiro / arrancada | 18 / 22 m/s básico; 19,5 / 28 com os bocais | `Ajustes.VOO_ALVO`, `Melhorias.arrancada_alvo` |
| Voo até superaquecer | 60 s básico (~1,1 km), 100 s com o radiador (~1,8 km), 182 s com o duplo (~3,3 km) | `Melhorias.calor_voo` |
| Esfriar no chão | 15 %/s (de 100 a 0 em ~7 s), 30 %/s com as células | `Melhorias.esfria_chao` |
| Esfriar na água, no mergulho, na cachoeira | rasante 45 %/s; mergulhar e passar na cachoeira zeram o calor | `Ajustes`, §89–90 |
| Lugares com nome | ~29 (15 regiões, 12 marcos, o Sumidouro e a Fundição) | `main.gd`, `Marcos.lugares` |
| Máquinas hostis | 12 mechas em 10 lugares, todos no oeste e no centro-sul; enxergam a 42 m | `InimigosVale.LUGARES`, `Vigia.VER` |

### 1.2 Esquema (uma célula = 100 m; norte em cima) [código + dedução]

Gerado pelo relevo e pela cobertura (`..` campo, `".` mata, `""` mata fechada, `^.` acima de 80 m, `^^` acima de 150 m, espaço = mar). `xx` = mecha.

```
          x: -1500    -1000     -500      0        500      1000    1500
 -1400                               ..                      ..FA
 -1300                       ..    ..""""..........      ....^...
 -1200       ......xx..............TV""""TV""""TV................
 -1100       ......".".OB^."."""""""""""""""""""."."...........
 -1000       ....".".^.^.^.^.^.^.""""""""""".................
  -900       ....".^.^^^^^^^^^.^.""""""""""""".....".......
  -800       ".".".^.^^^^^^^^^^^^^.""""""""""".".......".
  -700       ".".^.^.^^^^SE^^^^^^^."""""""""""."...".......
  -600       ..".".^.^^^^^^^^SU^.""""""""""""CO....".........
  -500     ......".^.^.^^^^^^^.CA"""""""""""""."...".........
  -400       xx"...".^.^.^.^.^.xx""""""""""""".".".".......RE
  -300       .."."."...^.FU^..."""""""""""."...".".".........
  -200       .."."."."......."."."."."......."...............
  -100       ".".".".".....xx"."."...........................
     0       ".".".".AR".....".......BA"."...................
   100       ..".".".".PA..".".........".........AM..........
   200       .."."."."."."."."...........".................
   300     CE......".".".xx".".............".............
   400       xx....".".TC"."."...............GI".".......
   500     ...."..."."."."."...............FZ............
   600     ...."..."...".".".....AN....xx..    ....  ..      RL
   700     ..".xx........................      ....
   800       "."."."...".................        ......
   900       "...".".".".................      ......CS
  1000       ............................      ..
  1100           ..FE........"....."...                    ..
```

BA base · SE cume da Serra · SU Sumidouro · CA Cachoeira · FU Fundição · CO As Colunas · TV Torres do Vento · OB Observatório · FA Farol Apagado · RE Represa Rachada · AM Árvore-Mãe e Platô das Flores · GI Sono dos Gigantes · AN O Anel e Campos do Sul · FZ Foz do Riacho · AR Os Arcos · PA Pátio das Máquinas · TC Torre Caída · CE Casco Encalhado · FE Fenda Escura · CS Cais Submerso · RL Ilha do Relé (o Arquipélago fica logo abaixo dela).

### 1.3 Distâncias da base [código + dedução]

| Lugar | x, z | Chão / topo (m) | Da base | A pé | Correndo | Voo de cruzeiro | O que tem |
|---|---|---|---|---|---|---|---|
| Antena (peça) | −52, 44 | 26 | 48 m | 23 s | 8 s | — | peça: antena |
| Sono dos Gigantes | 470, 400 | 29 / ~74 | 588 m | 4,7 min | 1,6 min | 33 s | peça: **radiador duplo** |
| O Anel | −190, 600 | 30 / ~80 | 588 m | 4,7 min | 1,6 min | 33 s | peça: células |
| Cachoeira | −290, −485 | 119 / 147 | 604 m | 4,8 min | 1,6 min | 34 s | memória |
| Foz do Riacho | 330, 590 | 0 | 637 m | 5,1 min | 1,7 min | 35 s | nada |
| Árvore-Mãe | 660, 110 | 40 / 110 | 661 m | 5,2 min | 1,7 min | 37 s | peça: asas |
| A Fundição | −580, −270 | 86 / ~117 | 661 m | 5,2 min | 1,7 min | 37 s | arena; peça: scanner na frente |
| Pátio das Máquinas | −680, 170 | 31 | 694 m | 5,5 min | 1,8 min | 39 s | nada |
| O Sumidouro | −312, −600 | 162 | 716 m | 5,7 min | 1,9 min | 40 s | peça: luz (na boca); memória (no salão) |
| Os Arcos | −730, 30 | 30 / 45 | 732 m | 5,8 min | 1,9 min | 41 s | memória; dupla de mechas a 40 m |
| A Torre Caída | −640, 440 | 26 / 44 | 754 m | 6,0 min | 2,0 min | 42 s | peça: molas; mecha grande a ~30 m |
| As Colunas | 430, −600 | 31 / 96 | 773 m | 6,1 min | 2,0 min | 43 s | peça: radiador de aletas |
| Cume da Serra | −564, −628 | 284 | 879 m | 7,0 min | 2,3 min | 49 s (mais a subida) | memória |
| Represa Rachada | 1102, −335 | 18 / 32 (parede a 40) | 1.163 m | 9,2 min | 3,1 min | 65 s | memória |
| Cais Submerso | 806, 902 | 0 / 25 | 1.176 m | 9,3 min | 3,1 min | 65 s | peça: barbatanas |
| Torres do Vento | 262, −1168 | 28 / 97 | 1.240 m | 9,8 min | 3,3 min | 69 s | memória |
| Casco Encalhado | −1206, 322 | 0 / ~14 | 1.240 m | 9,8 min | 3,3 min | 69 s | memória; mecha grande a ~110 m |
| Observatório | −700, −1088 | 77 / 102 | 1.332 m | 10,6 min | 3,5 min | 74 s | memória |
| Fenda Escura | −860, 1100 | 4 (fundo) | 1.363 m | 10,8 min | 3,6 min | 76 s | memória |
| Ilha do Relé | 1282, 648 | 12 / 58 | 1.415 m | 11,2 min | 3,7 min | 79 s | memória |
| Farol Apagado | 1338, −1338 | 71 / 133 | 1.922 m | 15,3 min | 5,1 min | 107 s | peça: bocais (balcão a 59 m) |

De costa a costa são uns 2,7 km: 21 minutos a pé, 7 correndo, 2,5 minutos voando. **[dedução]** Em tempo de voo a ilha é pequena: tudo cabe num raio de 2 minutos da base.

### 1.4 Distribuição e vazios [código + foto + dedução]

- **Densidade.** O quadrante noroeste (Serra, Sumidouro, Cachoeira, Fundição, Observatório) e o oeste do meio (Arcos, Pátio, Torre, a 270 m um do outro) concentram mais da metade do que há para ver. O leste tem marcos fortes mas espaçados (Árvore-Mãe, Represa, Farol) e um campo aberto enorme e liso entre eles (de x 100 a 1.000, z −300 a +600). **[foto]** `m16_do_plato`: o Platô das Flores visto do chão é um tapete verde-limão até o horizonte, com os gigantes como uma silhueta pequena lá no fundo.
- **Vazios medidos.** Os pontos de terra mais longe de qualquer lugar com nome são a faixa da costa oeste (x ≈ −1.200, z de −950 a +250: 600 a 700 m) e o sul do meio (x ≈ 100, z ≈ 1.150: 600 m). **[código]** Essas faixas têm só mechas (−1.180, −320) e (−1.050, 780). Voando, 600 m são 33 s: um vazio que se atravessa sem perceber não é problema; um vazio que só tem uma briga, é.
- **Cinco regiões só com nome.** Costa Quebrada, Encostas do Dique, Cabo do Vento, Arquipélago Raso e Chapada do Sudoeste mostram o nome e o "N de M", e nada mais. Somados à Clareira, Mata Fechada, Campos do Sul, Platô das Flores, Foz e Pátio das Máquinas, são **11 nomes sem nada** num total de 29. **[código]** Para o jogador, um nome na tela é uma promessa. Quando ela se repete onze vezes sem nada atrás, ele aprende que nome não quer dizer nada. **[dedução]**

### 1.5 Linhas de visão e marcos [código + foto + dedução]

Contei de uma grade de 100 m, na terra toda, quantos marcos altos (25 m ou mais acima do chão, mais o cume) cada ponto enxerga, com o relevo de verdade e uma copa de 12 m nas células de mata.

| De onde | Não vê nenhum marco | Vê 1 a 3 | Vê 4 ou mais |
|---|---|---|---|
| No chão (olho a 1,2 m) | 30% dos pontos | 34% | 36% |
| Voando a 40 m do chão | 0,2% | 9% | 91% |

- **Da base, no chão:** a Cachoeira, As Colunas, a Árvore-Mãe, O Anel, a Fundição, o Farol e a Serra. Sem as copas, também os gigantes e as Torres do Vento. **[dedução]** É um bom começo: o jogador nasce vendo seis direções com algo no fim.
- **Do cume:** dez marcos. A Serra funciona como mirante, como foi pedido na §25. **[dedução]**
- **Silhuetas que funcionam [foto]:** o Farol (vertical limpo contra o céu, `m06_farol_de_longe`), as Torres do Vento no horizonte, o telhado da Fundição na encosta (`v7_voo_alto`), a Árvore-Mãe (uma copa acima de todas) e a Serra (cone).
- **Silhuetas que não funcionam:** os gigantes, de longe, leem como entulho marrom baixo, não como corpos (`m11_gigantes_de_longe`) **[foto]**. A Represa só aparece de perto. Os Arcos, o Pátio, a Torre Caída (18 m dentro da mata), o Casco, o Cais, a Fenda e o Sumidouro não têm nada que se veja de longe: são achados sobrevoando **[dedução]**.
- **À noite** nenhum marco acende (`design_noite/v7_voo_alto`), apesar de a §10 pedir isso. O céu e a mata ficam legíveis, mas o jogador perde as referências. **[foto]**
- **Como o jogador sabe para onde ir.** Sem estrada e sem mapa, o jogo depende de três coisas: ver o marco, a bússola e o facho da peça. A bússola só mostra norte e sul, a base, a Fundição e as peças a menos de 300 m (com a antena). O facho da peça é um cilindro de 26 m de altura, 5 a 22 cm de raio e 16% de opacidade **[código]**: a mais de 100–150 m ele some **[dedução]**. Resultado: o jogador vê o marco, mas não sabe se o marco tem algo para ele, nem se já pegou o que havia lá.

### 1.6 Ordem provável de descoberta [dedução]

1. A antena (48 m, à vista do nascimento). Bom primeiro passo.
2. A primeira coisa que puxa é a **caveira da bússola** (a Fundição, a 661 m). É o único ponto fixo da bússola além da base. O jogador que quer "fazer alguma coisa" vai primeiro para a arena de luta.
3. Os marcos que se veem da base: Anel e gigantes (588 m), Árvore-Mãe (661 m), Cachoeira (604 m) e Colunas (773 m). Quatro dessas cinco têm peça. **O radiador duplo sai aqui.**
4. Seguindo o rio, a Cachoeira e a boca do Sumidouro. No caminho, perto de (−250, −330), mora um mecha **[código]**.
5. O oeste: Arcos, Pátio, Torre (com o mecha grande a 30 m da peça das molas).
6. Por último a borda: Represa, Cais, Relé, Torres, Observatório, Casco, Fenda e Farol.

As máquinas ficam bem no caminho da ordem natural (base → rio → cachoeira; base → ruínas). O "leste seguro" está certo, mas a primeira briga provavelmente chega antes do primeiro sossego de verdade.

### 1.7 Barreiras, altura, água: o voo trivializa o relevo? [código + dedução]

**Sim.** Com 60 s de voo, 1 km de alcance e 7 s para esfriar no chão, o calor vira só um ritmo (voa um minuto, pousa sete segundos). Ele não chega a ser obstáculo:

- **Altura:** a Serra é o único desafio vertical do robô básico. Subir custa 3× o calor (~5 %/s), e chegar dos 86 m da Fundição aos 284 m do cume voando reto deve superaquecer. Todo o resto fica a menos de 110 m (o balcão do Farol a 59 m custa uns 35% de calor).
- **Água:** o rio corta a ilha de norte a sul e a costa está a 1 km de qualquer ponto. A água sempre esfria, e mergulhar zera o calor. Ela nunca barra nada: dá até para mergulhar sem as barbatanas (confirmado pelo usuário na §86).
- **Mar:** o limite fica a 550 m da costa e funciona.
- **Mata fechada:** atrapalha o chão (a vista e as copas), não o voo.

O que o gênero faz bem aqui, falando só de mecânica: num jogo de exploração com voo, o relevo vira desafio quando o recurso do voo é escasso **e** o mundo tem lugares pensados para essa escassez: um platô que só se alcança planando de um ponto mais alto, uma ilhota a 1,5 km do último pouso, uma corrente de ar quente que estende o voo. Aqui a escassez existe por uns minutos e o mundo não foi desenhado em volta dela.

### 1.8 Identidade de cada lugar [foto + código + dedução]

| Lugar | Identidade | O que fazer lá |
|---|---|---|
| Base e clareira | alta: hangar, Faísca caído, drone | instalar, oficina |
| Cachoeira e poço | alta | esfriar, nadar, memória |
| Sumidouro | alta (a única peça vertical de caverna) | voar por dentro, memória, peça na boca |
| Fundição | muito alta | ondas de luta |
| Sono dos Gigantes | alta de perto, fraca de longe | pousar no gigante, peça |
| Farol, Torres, Represa, Relé, Cais | média a alta | pousar, uma peça ou memória |
| Árvore-Mãe, Anel, Colunas | média (formas simples, sem história) | peça |
| Arcos, Torre Caída | média | peça ou memória, com mecha perto |
| Observatório, Casco | média, mas feitos de caixas (ver §4) | memória |
| Pátio das Máquinas | baixa | nada |
| Fenda Escura | média, mas não é escura (o teto saiu, §82) | memória |
| 5 regiões novas, Foz, Campos, Platô, Mata Fechada | só nome | nada |

Nenhum lugar tem uma **ação própria**. Todos funcionam igual: chegar, tocar uma caixa ou um cristal e ir embora. **[código]**

### 1.9 A curva das 10 peças [código + dedução]

| Ordem provável | Peça | Distância | O que muda | Leitura |
|---|---|---|---|---|
| 1 | Antena | 48 m | bússola mostra peças a menos de 300 m | boa como primeira; mas da base nenhuma outra peça está no alcance, então ela fica muda na primeira saída |
| 2 | **Radiador duplo** | 588 m, a 31 m do chão | voo de 60 s para 182 s | **quebra a curva**: chega cedo e torna o radiador de aletas inútil (o duplo vale sozinho). Depois dele, o calor quase não existe (3,3 km de alcance numa ilha de 2,7 km) |
| 3 | Células | 588 m | esfria no chão em 3,5 s em vez de 7 s | quase imperceptível |
| 4 | Asas | 661 m | planar segurando L3 ou X | só serve se o calor pesa, e com o duplo ele não pesa |
| 5 | Scanner | ~560 m | fichas de texto de bichos e mechas | sem valor para quem não lê; não há caderno |
| 6 | Luz do peito | ~570 m | lanterna | só pesa no Sumidouro e à noite, e a noite já é legível (foto) |
| 7 | Molas | ~740 m | pulo 25% mais alto, pouso sem tranco | irrelevante num jogo em que se voa desde o primeiro minuto |
| 8 | Radiador de aletas | 758 m | 60 → 100 s | chega tarde demais, ou nunca vale |
| 9 | Barbatanas | 1.176 m | nado rápido mais veloz (13 m/s contra 10) | a água é opcional |
| 10 | Bocais | 1.922 m | arrancada 22 → 28, cruzeiro +1,5 | o prêmio mais longe é dos mais fracos |

Nenhuma peça quebra o jogo no mau sentido. O problema é o contrário: **quase nenhuma muda o jeito de jogar**, e a única que muda (o radiador duplo) chega no começo. As peças não abrem lugares, como a §12.2 previa ("radiador para zonas quentes, vedação para mergulhar...").

### 1.10 A curva das 10 memórias [código + foto + dedução]

- **Textos [código]:** são bons. Têm o tom da §87, nenhum vilão, e cada um fecha numa imagem ("hoje o mar está lindo"). O do Casco é o clímax da história (Faísca decide continuar), mas é só um dos dez e fica no oeste hostil.
- **Ordem:** não há. Cada memória se basta, e o "1 de 10" só conta. Ninguém monta uma história em ordem.
- **Onde ficam:** metade no oeste e no norte (Arcos com dois mechas a 40 m, Casco com um grande a ~110 m, Observatório, Fenda, Torres). As lembranças mais tristes e bonitas ficam atrás das brigas.
- **Forma [foto, `ideias_2026_11_18`]:** um cristal âmbar pequeno; ao tocar, a tela escurece e aparecem uns 80 palavras em letra branca pequena sobre fundo escuro, com música. **Para uma criança que não lê, a memória é uma tela escura com letras.**

## 2. Laço de jogo e progressão

### 2.1 O que o jogador faz minuto a minuto [código + dedução]

- **Laço curto (30 s a 2 min):** voar até um marco, pousar, tocar a caixa ou o cristal, o drone vem e instala (3 s parado), decolar. No caminho, bichos que fogem, chuva, capim que abre.
- **Laço médio (10 a 20 min):** varrer uma região atrás dos marcos. Não há registro do que já foi visto além do "N de M" ao chegar.
- **Laço de luta, separado:** a Fundição (ondas sem fim, experiência, sucata, núcleos, chips) compra armas e defesas na oficina. Essa economia só serve à própria luta: nenhum material ajuda a explorar, e nenhuma peça de exploração ajuda a lutar. **São dois jogos que não se falam.**

### 2.2 Quanto conteúdo há de verdade [dedução]

São 10 peças, 10 memórias e ~29 nomes. Num ritmo calmo (voo de 30 a 80 s até cada lugar e 1 a 4 minutos lá), isso dá de **1h30 a 3h** para ver tudo uma vez. Depois disso sobram o passeio, o ciclo do dia (60 minutos reais) e a Fundição.

Para um jogo "sem objetivos" isso basta, **se** o passeio em si recompensa. Hoje o passeio recompensa pela vista e pelo movimento, que são o ponto forte. Nenhuma das duas coisas acumula: o jogo não guarda nada do que o jogador viu ou fez fora da lista.

### 2.3 Onde o ritmo cai [dedução]

1. **Depois do radiador duplo**, que deve sair nos primeiros 10–20 minutos. O voo vira infinito, e a única tensão do mundo cozy acaba.
2. **Nas regiões só com nome**, a cada "lugar descoberto" vazio.
3. **Depois da última peça**, porque não há fim, nem cena, nem mudança no mundo.
4. **À noite**, porque some a referência visual sem ganhar outra (luzes, bichos noturnos com papel, estrelas para olhar no Observatório).

### 2.4 Calor e máquinas somam ou atrapalham? [código + dedução]

- **Calor:** soma pouco. A ideia é boa e é a "assinatura" do jogo (esfriar na água, na cachoeira, na chuva, com o aviso azul de "resfriado"). Mas só pesa nos primeiros minutos, e depois some de vez. Para somar, ele precisa de lugares que dependam dele (ver propostas 1 e 9).
- **Máquinas no mundo (12):** com o oeste hostil, fazem sentido como tempero, como o usuário pediu. Atrapalham onde ficam em cima das recompensas cozy (memória dos Arcos, peça das molas na Torre) e no caminho natural da base para a cachoeira.
- **Fundição:** é o maior bloco de sistema do jogo (§66–71: ondas, 6 modos de tiro, granadas, mísseis com trava, escudo, vida extra, níveis, chefes, placar, resumo de rodada). Com o tiro sem calor (§88) o equilíbrio está aberto. Ela não fere a proposta por existir à parte. Fere porque a bússola a anuncia desde o primeiro segundo com uma caveira, num jogo para crianças em que "ninguém é destruído".

### 2.5 O final [código]

**Não existe.** Achar as 10 peças ou ler as 10 memórias não dispara nada (não há cena, aviso nem mudança no mundo). O nome "Farol Apagado" pede um final (acender o farol), e a história da §87 tem um arco pronto: o Faísca passou a consciência ao robô, e o robô carrega a memória dos que se foram.

### 2.6 Primeiro contato [código + foto]

- Não há tela de título nem "novo jogo". Depois da tela de carregamento o robô já está no estrado da base.
- **Nenhum comando é ensinado no jogo.** Eles ficam numa tabela de texto na pausa (`n7_comandos`) e numa dica sorteada a cada abertura dela.
- O controle tem **22 ações**, várias em botões dobrados **[código]**:
  - **L3** corre no chão, liga o voo no ar, corta os jatos no voo e acelera o nado;
  - **R3** para no ar e, no chão, é a espada;
  - **O** esquiva no chão, faz manobra no ar e desce na água;
  - **X no voo corta os jatos** (§65): a criança que aperta "pular" para subir cai.
- **A tabela de comandos está desatualizada [código]:** diz "Parar no ar · frear: L2 · O", mas desde a §88 o O no voo é a manobra (giro), e a manobra não aparece na tabela.
- O Faísca caído e o drone na base são a melhor introdução que o jogo tem, mas nada chama a atenção do jogador para eles (o Faísca só entra na história por uma ficha do scanner e pela memória do Casco).

## 3. Usabilidade

### 3.1 HUD [foto + código]

- **Bússola (`h3_voando`, `h2_mirando_quente`):** faixa escura no alto com N, L, S, O, a casinha da base, a caveira da Fundição e os triângulos das peças. Ela é sóbria e lê bem. Falta o que importa para explorar: os lugares já visitados, as memórias por ler e o marcador que o próprio jogador põe (já existe no código, `marcar` na seta para baixo, mas ninguém fica sabendo).
- **Calor:** arco verde-água fino embaixo, no centro. Sobre o capim verde-amarelo ele quase some **[foto, `h3_voando` e `h2`]**. Para o recurso principal do voo, o contraste está baixo.
- **Velocidade e altura:** "68 km/h · 25 m do chão", em texto pequeno no canto. Para quem não lê é ruído; para quem lê é pouco útil.
- **Nome do lugar e avisos:** texto no terço de cima, com sombra. "Peça encontrada: Molas · pouse: o drone vem instalar · 3 de 10" é uma frase longa e só funciona para quem lê.

### 3.2 Pausa e menus [foto]

- **Pausa (`n6_pausa`):** limpa e com bom foco, mas só tem Continuar, Voltar à base, Comandos, Ajustes e Sair. **Não há uma página de progresso:** peças achadas, memórias para reler, lugares visitados ou bichos vistos.
- **Oficina (`n3_oficina_pecas`):** legível, com ícones de traço e cadeados. "Peça não encontrada · em algum lugar da ilha", repetido oito vezes, não dá pista nenhuma. Basta mostrar a silhueta ou o ícone da peça (o jogador sabe o que procura sem saber onde).

### 3.3 Retorno das ações [código; som não ouvido]

O jogo tem retorno físico rico: vibração por ação, poeira, capim que deita, respingo, pouso em três graus, o drone que comemora. O fraco é o retorno de **sentido**: tocar um cristal escurece a tela; achar uma peça escreve uma frase. Nada no mundo muda quando o jogador faz algo (uma torre que volta a girar, uma luz que acende, um bicho que passa a seguir o robô).

### 3.4 Acessibilidade [código + dedução]

- **Criança que não lê:** fica sem memórias, fichas do scanner, oficina, comandos, avisos e os nomes dos lugares. O que sobra é voar e olhar, que é muito, mas é tudo o que sobra.
- **Daltonismo:** quase todos os sinais são por cor: verde-água (peça, escudo, frio), laranja (dano, foco, mira), vermelho (aviso do mecha, superaquecido) e azul-claro ("resfriado"). Laranja e verde-água se separam bem; já o aviso vermelho do mecha contra a mata verde é o par que mais falha em quem não distingue vermelho de verde. O aviso também pisca, o que ajuda.
- **Enjoo no voo [código]:** a câmera abre de 70° a 90°, inclina até ~10° nas curvas, treme acima da arrancada e faz o giro de caça (volta inteira). Não há opção para tirar a inclinação, o tremor ou o aumento do campo de visão.
- **Controle:** dá para trocar a sensibilidade e inverter o eixo Y, mas não dá para trocar os botões. O teclado também dobra teclas (Shift corre e voa; C esquiva, desce na água e era a freada).

## 4. Arte e leitura visual

- **Paleta [foto, `design_dia`]:** o visual novo é coerente e alegre: luz em faixas, sombra azulada, céu saturado, folhas do MegaKit. O capim de perto domina o quadro. Com a câmera a 2,5 m, 50 a 60% da imagem é lâmina verde-limão (`v4_campo_aberto`, `v10_mata_por_dentro`), e a câmera da "mata por dentro" mostra campo, não mata. Nos campos grandes do leste, a cor única até o horizonte cansa (`m16_do_plato`).
- **Robô contra o fundo:** de dia, o branco e o cinza-azulado do robô se destacam do capim pelo valor (`v14_robo_no_capim`, `h3_voando`). À noite ele vira azul-escuro sobre verde-escuro e quase some (`design_noite/v14_robo_no_capim`). Os leds do corpo são fracos (§65 tirou a lanterna). De perto, a textura da cabeça aparece em pixels grandes (`h2_mirando_quente`): é o quadro em que o jogador mais olha para ele.
- **Pacotes misturados:** a vegetação (MegaKit) e os bichos (Quaternius) combinam. Já as construções feitas de caixa por código (Observatório, Casco, Represa, as paredes da Fundição) são chapadas e de arestas duras, outra linguagem (`marcos_oeste`, `m01_represa_da_lagoa`). Os mechas com paletas sorteadas (rosa e azul-claro, §52) e as peças do Kenney na Fundição são uma terceira linguagem. Fica cada vez mais visível conforme a mata melhora.
- **Legibilidade de longe:** ver §1.5. Os marcos verticais funcionam; os gigantes, não; e de noite nada acende.
- **Água:** de perto (`m01_represa_da_lagoa`) é azul-escuro uniforme com um ruído miúdo, mais pesada que o resto da cena.

## 5. Propostas, em ordem de impacto

### Ajustes (usam o que já existe)

**1. Refazer a curva das peças em volta do calor e da distância.** Esforço: pequeno.
- *Problema:* o radiador duplo chega cedo e apaga o calor; o prêmio mais longe é fraco; as peças "de longe" não pedem nada do robô.
- *Como:*
  - o radiador duplo vai para o balcão do Farol ou para o cume da Serra, onde o básico não chega sem parar para esfriar;
  - os bocais vão para os gigantes;
  - o radiador de aletas fica num lugar do meio que o jogador vê da base (As Colunas serve);
  - juntar molas e células numa peça só, e usar a vaga para uma peça que abra lugar (ver proposta 9).
- *Como saber:* num jogo de teste, o radiador duplo sai depois dos 45 minutos e o jogador superaquece pelo menos três vezes antes dele. Contar no progresso salvo a hora em que cada peça foi pega.

**2. Memórias que se entendem sem ler.** Esforço: médio.
- *Problema:* o coração da história é texto, e uma parte do público não lê.
- *Como:* ao tocar o cristal, uma cena curta no próprio lugar, com a câmera parada. Vultos de luz âmbar (formas simples de pessoas e robôs, sem rosto nem personagem copiado) fazem o que a memória conta: medem a queda, desligam as luzes no salão, giram a primeira torre. O texto fica como legenda que se pode abrir. Dá para fazer com o que o jogo já tem (partículas, luzes, poses por código).
- *Como saber:* uma criança de 4 a 6 anos, depois de ver uma, consegue dizer "o que aconteceu ali" e pede para ver outra.

**3. A bússola do explorador.** Esforço: pequeno.
- *Problema:* a bússola puxa para a luta e não ajuda a explorar.
- *Como:*
  - tirar a caveira (a Fundição já se vê de longe, pelo telhado e pela fumaça) ou trocá-la por uma engrenagem neutra que só aparece depois da primeira visita;
  - um ícone âmbar para cada memória ainda não lida que esteja a menos de 300 m (igual à antena faz com as peças);
  - pontinhos apagados nos lugares já visitados.

  Nada aponta para lugar não visitado de longe, o que respeita o "não facilitar demais".
- *Como saber:* no teste, o primeiro lugar visitado deixa de ser a Fundição.

**4. Controle de criança e tabela corrigida.** Esforço: pequeno a médio.
- *Problema:* a criança aperta X para subir e cai; vários botões têm duas funções; a tabela da pausa está errada.
- *Como:*
  - X no voo sobe (ou não faz nada), e cortar os jatos fica só no L3;
  - a espada sai do R3 e vai para um botão próprio, ou fica só na Fundição;
  - consertar a linha "Parar no ar · frear" e incluir a manobra;
  - um ajuste "comandos simples" que tira do controle a granada, a roda, os mísseis e a espada fora da Fundição.
- *Como saber:* a criança voa 5 minutos sem cair sem querer; ninguém pergunta "como para?".

**5. Ensinar sem texto no primeiro minuto.** Esforço: médio.
- *Problema:* hoje não há ensino nenhum.
- *Como:*
  - o desenho do botão (glifo do controle, sem palavra) aparece ao lado do robô na primeira vez que a ação faz sentido: o X quando ele para perto de um degrau alto, o L3 quando ele está no ar e o pulo duplo, o círculo de manobra na primeira vez que ele voa 10 s;
  - cada glifo some para sempre depois de usado três vezes;
  - o drone faz a primeira viagem junto: sai da base e voa devagar até a antena e depois até o marco mais perto (O Anel), parando no ar para esperar.
- *Como saber:* uma pessoa que nunca jogou chega à primeira peça fora da base sem abrir a pausa.

**6. Página "Caderno" na pausa.** Esforço: pequeno a médio.
- *Problema:* não há registro do que foi feito nem como reler.
- *Como:* três abas de figuras:
  - **Ilha:** o contorno da ilha com só os lugares já visitados desenhados, como um caderno de campo; nada do que falta aparece;
  - **Memórias:** o cristal e a cena para rever;
  - **Bichos:** as figuras do que o scanner já leu.

  Isso também dá ao scanner o caderno que a §65 deixou para depois.
- *Como saber:* o jogador abre o caderno sem que ninguém peça, e o usa para escolher para onde ir.

**7. Luzes de noite nos marcos e um robô que aparece no escuro.** Esforço: pequeno.
- *Problema:* à noite somem as referências e o próprio robô.
- *Como:*
  - luz vermelha piscando no alto das Torres do Vento e da torre do Relé;
  - brasa na chaminé da Fundição;
  - os cristais de memória visíveis em âmbar a 150 m;
  - os leds do robô com uma borda clara de contorno à noite (só no corpo, sem iluminar o chão).
- *Como saber:* de noite, do cume, contam-se pelo menos quatro luzes; o robô se acha na tela em menos de meio segundo nas fotos noturnas.

**8. Tirar a luta de cima do sossego.** Esforço: pequeno.
- *Problema:* recompensas cozy guardadas por mechas, e um mecha no caminho base → cachoeira.
- *Como:*
  - levar o mecha de (−250, −330) para longe do rio;
  - a dupla dos Arcos para o Pátio das Máquinas, que é o lugar delas e hoje não tem nada;
  - afastar o grande da Torre para uns 120 m da peça;
  - manter o oeste hostil, mas com o prêmio a uma distância que deixe escolher entre passar escondido e brigar.
- *Como saber:* um jogador que foge de toda briga consegue as 10 memórias.

### Conteúdo novo

**9. Peças que abrem lugares.** Esforço: médio.
- *Problema:* hoje nenhuma peça abre lugar novo.
- *Como:* três ou quatro lugares ganham uma parte que só se alcança com uma peça:
  - **barbatanas:** o contêiner aberto no fundo do Cais e uma galeria submersa na Represa (correnteza que o nado comum não vence);
  - **luz do peito:** a câmara de cristais do Sumidouro fica escura de verdade, e um bicho só aparece com luz;
  - **asas:** a ilhota do sul do Arquipélago, a mais de um voo de jato da costa, que se alcança planando do alto do Farol ou do Relé;
  - **radiador:** uma coluna de ar quente na Fundição ou nas chaminés que leva até o alto do paredão.

  Respeita o "não facilitar": o jogador vê o lugar antes e volta depois.
- *Como saber:* cada peça nova é usada pelo menos uma vez no jogo de teste, e o jogador lembra onde voltar sem anotar.

**10. Um final: acender o Farol.** Esforço: médio.
- *Problema:* hoje não há final.
- *Como:* com as 10 memórias lidas, os cristais respondem e o drone indica o Farol. Lá, uma última memória (sem texto: o Faísca e as pessoas, em vultos âmbar) e o robô acende a lente. Daí em diante o farol gira à noite e a ilha ganha vaga-lumes e bichos perto dele. Depois vêm os créditos, e o jogo continua. Não precisa de chefe nem de luta.
- *Como saber:* o jogador que leu algumas memórias passa a procurar as outras para ver o que acontece; quem termina diz que "acabou bem".

**11. Uma ação por lugar marcante (a "diversão no ar" que ficou para o fim).** Esforço: grande, mas sai aos poucos.
- *Problema:* todos os lugares funcionam igual: chegar, tocar, ir embora.
- *Como:* sem cronômetro e sem placar, só pelo movimento:
  - atravessar o Anel acende o aro;
  - passar entre as pás das Torres faz uma delas voltar a girar;
  - mergulhar da Cachoeira até o fundo do poço solta um cardume que acompanha o robô por um tempo;
  - sentar no cume ao pôr do sol mostra a ilha inteira com os lugares visitados acesos;
  - pousar no alto da Árvore-Mãe faz os pássaros pousarem em volta.

  Cada ação muda algo no mundo, e a mudança fica.
- *Como saber:* o jogador repete a ação sem precisar (é o sinal de que ela é gostosa por si).

**12. Bichos com papel.** Esforço: médio.
- *Problema:* os bichos só fogem; o jogo não guarda nada da relação com eles.
- *Como:* sentar já faz os bichos chegarem (dica da pausa). Dá para crescer em cima disso, só com olhar:
  - um cervo que passa a seguir o robô de longe depois de três visitas sentado;
  - coelhos que mostram uma toca;
  - um cardume que leva ao contêiner do Cais.

  Tudo entra no caderno (proposta 6) com a figura.
- *Como saber:* o jogador procura um bicho que já viu, pelo nome ou pela figura.

## 6. O que eu cortaria

- **A caveira da bússola** e qualquer ícone de luta fora da Fundição.
- **A árvore de armas da Fundição, quase toda.** Ficam a pistola, a espada e no máximo um modo de tiro. Saem as granadas com arco, a roda de armas, os mísseis com trava múltipla, o tiro duplo e os níveis de experiência. É muito sistema para manter equilibrado num jogo cujo pilar é o sossego, e ele não conversa com a exploração. Se o usuário quer o "outro lugar" de luta que mencionou na §54, esse conteúdo vai para lá.
- **O "N de M" das regiões só com nome.** O nome pode ficar, sem a contagem e sem "lugar descoberto". A contagem fica só para os lugares que têm algo.
- **Uma das duas peças fracas** (molas ou células): juntar numa só e usar a vaga para uma peça que abra lugar.
- **O texto de velocidade e altura** no voo. A altura pode virar uma marca sem número, ou sair.
- **A cena do Pátio das Máquinas como nome vazio:** ou ganha as máquinas da proposta 8, ou sai da lista.

## 7. Onde estou questionando decisões do dono

- **"Não facilitar demais" contra "público inclui crianças pequenas que não leem".** Hoje o "não facilitar" acaba sendo "deixar sem informação" (sem caderno, sem pista na oficina, sem ensino), e isso pesa mais em quem não lê. Proponho separar: o desafio fica no mundo (calor, distância, lugares que pedem peça); a informação sobre o que já foi feito pode ser generosa.
- **"Interface sóbria" contra "criança que não lê".** A sobriedade é possível com figuras: glifos de botão, ícones de traço (já existem em `scripts/icones.gd`), cenas em vez de texto. Sóbrio não precisa ser escrito.
- **"Ninguém é destruído"** é respeitado no código, mas a Fundição, com explosões, mísseis, chefes e caveira, comunica outra coisa para uma criança. Não peço para tirar a Fundição; peço para não a anunciar.

## 8. O que não deu para verificar

- Nada foi jogado com controle. Sensação de voo, câmera, giro de caça e enjoo saem da leitura do código e das fotos paradas.
- Nenhum som foi ouvido. O retorno sonoro das ações, a música das memórias e a fala do drone ficam sem avaliação.
- As linhas de visão são uma conta minha sobre o mapa de alturas, com copa de 12 m em toda célula de mata. Não contam a névoa, o desfoque do fundo nem as árvores de verdade. Servem para comparar regiões, não como número exato.
- Os tempos de conteúdo (1h30 a 3h) são estimativa.
- Não vi chuva, a Fundição por dentro, o Sumidouro por dentro nem o Cais debaixo d'água nesta rodada (só imagens antigas da doc).
- `docs/mapa/mapa_pecas.jpg` mostra a luz do peito perto do Pátio das Máquinas, mas o código põe a peça na boca do Sumidouro. A imagem deve ser anterior à mudança da §83; não rodei `--mapa --so-pecas` de novo para conferir.
- Daltonismo foi avaliado só pela lista de cores do código, sem simulação.
