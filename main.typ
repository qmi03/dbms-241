#import "@preview/red-agora:0.1.1": project

#show: project.with(
  title: "PostgreSQL vs HBase", subtitle: "Database mamangement system - CO3021", authors: (
    "Đỗ Nguyễn An Huy - 2110193", "Phạm Võ Quang Minh - 2111762", "Nguyễn Ngọc Phú - 2114417", "Nguyễn Xuân Thọ - 2112378", "Trần Nguyễn Phương Thành - 2110541",
  ), mentors: ("MEng. Lê Thị Bảo Thu",), branch: "Software Engineering", academic-year: "2024-2025", footer-text: "HCMUT - CSE", school-logo: image("images/HCMUT.png", width: 60%),
)

#include "work_division.typ"

#include "chapters/introduction.typ"
#include "chapters/data_storage_management.typ"
#include "chapters/query_processing.typ"
#include "chapters/transaction.typ"
#include "chapters/concurrency.typ"
#include "chapters/recovery.typ"
#include "chapters/conclusion.typ"
#include "chapters/references.typ"
#set heading(numbering: "1.1.1.a")
#show heading: it => {
  it
  v(.5em)
}
#set enum(numbering: "1.a.")
