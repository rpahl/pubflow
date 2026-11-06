// pubflow's Typst template for PDF files made with Typst: pandoc's
// default template (pandoc -D typst, pandoc 3.8) with its partial
// template.typst inlined, and
// - headings numbered "1.1" (pandoc writes unnumbered ones with
//   `numbering: none`);
// - a header and a footer line from the metadata `header-left`,
//   `header-center`, `header-right`, `footer-left`, `footer-center` and
//   `footer-right` (pandoc escapes them); "Page x / N" at the right of the
//   footer unless `footer-right` is set (an empty one is passed as
//   `footer-right-empty`, as pandoc treats an empty string as unset);
// - captions above tables, below images; table cells neither justified
//   nor hyphenated;
// - the title block only if the variable `title-block` is set (pubflow
//   leaves it out when front matter replaces it; the title and author stay
//   in the document's properties);
// - `header-includes` before the document (pubflow writes the page
//   orientation and the caption labels there);
// - `divider` for pandoc >= 3.10.1, which writes horizontal rules as
//   `#divider()` (built into typst >= 0.15; pandoc's own fallback fails on
//   older typst), older pandoc `#horizontalrule`.

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))
#let divider = if sys.version >= version(0, 15) { std.divider } else { () => horizontalrule }

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

#set table(
  inset: 6pt,
  stroke: none
)

// Table cells: text neither justified nor hyphenated (as in Word and HTML)
#show table: set par(justify: false)
#show table: set text(hyphenate: false)

#show figure.where(
  kind: table
): set figure.caption(position: $if(table-caption-position)$$table-caption-position$$else$top$endif$)

#show figure.where(
  kind: image
): set figure.caption(position: $if(figure-caption-position)$$figure-caption-position$$else$bottom$endif$)

$if(highlighting-definitions)$
// syntax highlighting functions from skylighting:
$highlighting-definitions$

$endif$
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

// A header or footer line: left, centre and right part
#let pubflow-line(parts) = {
  set text(size: 0.85em)
  grid(
    columns: (1fr, auto, 1fr),
    column-gutter: 1em,
    align: (left, center, right),
    ..parts.map(part => if part == none { [] } else { part }),
  )
}

#let conf(
  title: none,
  subtitle: none,
  authors: (),
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  margin: (top: 2.5cm, bottom: 2cm, x: 2.5cm),
  paper: "a4",
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: "1.1",
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  pagenumbering: "1",
  header: (none, none, none),
  footer: (none, none, none),
  title-block: true,
  doc,
) = {
  set document(
    title: title,
    keywords: keywords,
  )
  set document(
      author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set page(
    paper: paper,
    margin: margin,
    numbering: pagenumbering,
    columns: cols,
    header: pubflow-line(header),
    footer: pubflow-line(footer),
  )

  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)

  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
  }

  if title-block { block(below: 1em, width: 100%)[
    #if title != none {
      align(center, block[
          #text(weight: "bold", size: 1.5em)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
          #(
            if subtitle != none {
              parbreak()
              text(weight: "bold", size: 1.25em)[#subtitle]
            }
           )])
    }

    #if authors != none and authors != [] {
      let count = authors.len()
      let ncols = calc.min(count, 3)
      grid(
        columns: (1fr,) * ncols,
        row-gutter: 1.5em,
        ..authors.map(author => align(center)[
          #author.name \
          #author.affiliation \
          #author.email
        ])
      )
    }

    #if date != none {
      align(center)[#block(inset: 1em)[
          #date
        ]]
    }

    #if abstract != none {
      block(inset: 2em)[
        #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
      ]
    }
  ] }

  doc
}

$if(smart)$
$else$
#set smartquote(enabled: false)

$endif$
$for(header-includes)$
$header-includes$

$endfor$
#show: doc => conf(
$if(title)$
  title: [$title$],
$endif$
$if(subtitle)$
  subtitle: [$subtitle$],
$endif$
$if(author)$
  authors: (
$for(author)$
$if(author.name)$
    ( name: [$author.name$],
      affiliation: [$author.affiliation$],
      email: [$author.email$] ),
$else$
    ( name: [$author$],
      affiliation: "",
      email: "" ),
$endif$
$endfor$
    ),
$endif$
$if(keywords)$
  keywords: ($for(keywords)$$keyword$$sep$,$endfor$),
$endif$
$if(date)$
  date: [$date$],
$endif$
$if(lang)$
  lang: "$lang$",
$endif$
$if(region)$
  region: "$region$",
$endif$
$if(abstract-title)$
  abstract-title: [$abstract-title$],
$endif$
$if(abstract)$
  abstract: [$abstract$],
$endif$
$if(thanks)$
  thanks: [$thanks$],
$endif$
$if(margin)$
  margin: ($for(margin/pairs)$$margin.key$: $margin.value$,$endfor$),
$endif$
$if(papersize)$
  paper: "$papersize$",
$endif$
$if(mainfont)$
  font: ("$mainfont$",),
$endif$
$if(fontsize)$
  fontsize: $fontsize$,
$endif$
$if(mathfont)$
  mathfont: ($for(mathfont)$"$mathfont$",$endfor$),
$endif$
$if(codefont)$
  codefont: ($for(codefont)$"$codefont$",$endfor$),
$endif$
$if(linestretch)$
  linestretch: $linestretch$,
$endif$
$if(section-numbering)$
  sectionnumbering: "$section-numbering$",
$endif$
$if(page-numbering)$
  pagenumbering: "$page-numbering$",
$endif$
$if(linkcolor)$
  linkcolor: [$linkcolor$],
$endif$
$if(citecolor)$
  citecolor: [$citecolor$],
$endif$
$if(filecolor)$
  filecolor: [$filecolor$],
$endif$
  header: (
    $if(header-left)$[$header-left$]$else$none$endif$,
    $if(header-center)$[$header-center$]$else$none$endif$,
    $if(header-right)$[$header-right$]$else$none$endif$,
  ),
  footer: (
    $if(footer-left)$[$footer-left$]$else$none$endif$,
    $if(footer-center)$[$footer-center$]$else$none$endif$,
    $if(footer-right)$[$footer-right$]$elseif(footer-right-empty)$none$else$context [Page #counter(page).display() / #counter(page).final().first()]$endif$,
  ),
  cols: $if(columns)$$columns$$else$1$endif$,
  title-block: $if(title-block)$true$else$false$endif$,
  doc,
)

$for(include-before)$
$include-before$

$endfor$
$if(toc)$
#outline(
  title: auto,
  depth: $toc-depth$
);
$endif$

$body$

$if(citations)$
$for(nocite-ids)$
#cite(label("${it}"), form: none)
$endfor$
$if(csl)$

#set bibliography(style: "$csl$")
$elseif(bibliographystyle)$

#set bibliography(style: "$bibliographystyle$")
$endif$
$if(bibliography)$

#bibliography(($for(bibliography)$"$bibliography$"$sep$,$endfor$)$if(full-bibliography)$, full: true$endif$)
$endif$
$endif$
$for(include-after)$

$include-after$
$endfor$
