#align(center)[
  #text(size: 20pt)[
    *Work division*
  ]
]

== Theory work

Meaning of symbols:
- #emoji.checkmark.box - Assigned and done (100%)
- #emoji.square.yellow - Secondary contribution

#figure(caption: "Theory work division")[
  #set text(size: 10pt)
  #table(
    columns: (auto, auto, auto, auto, auto, auto),
    inset: 10pt,
    align: horizon,
    table.header(
      [Name], [*Physical storage*], [*Query processing*], [*Transaction*], [*Concurrency control*], [*Recovery*],
    ),
    [Đỗ Nguyễn An Huy (2110193)], [], [#emoji.square.yellow], [#emoji.square.yellow], [], [#emoji.checkmark.box],
    [Phạm Võ Quang Minh (2111762)],  [#emoji.checkmark.box], [], [], [], [],
    [Nguyễn Ngọc Phú (2114417)], [], [], [#emoji.checkmark.box], [], [],
    [Nguyễn Xuân Thọ (2112378)],  [], [], [], [#emoji.checkmark.box], [],
    [Trần Nguyễn Phương Thành (2110541)],  [], [#emoji.checkmark.box], [], [], [],
  )
]

== Application work

#figure(caption: "Application work division")[
  #set text(size: 10pt)
  #table(
    columns: (auto, 1fr),
    inset: 10pt,
    align: horizon,
    table.header(
      [Name], [Role],
    ),
    [Đỗ Nguyễn An Huy (2110193)], [
      #set align(left)
      - Terminal frontend web interface.
      - Command execution model so that commands can be implemented.
      - `ls` command
      - `cat` command
    ],
    [Phạm Võ Quang Minh (2111762)],  [
      #set align(left)
      - Setup database
      - `cp` command
      - `mv` command
    ],
    [Nguyễn Ngọc Phú (2114417)], [
      #set align(left)
      - `unalias` command
      - `alias` command
    ],
    [Nguyễn Xuân Thọ (2112378)],  [
      #set align(left)
      - 
    ], 
    [Trần Nguyễn Phương Thành (2110541)],  [],
  )
]