import Foundation

/// A large invented archive for search performance: 60 copies of the reviewed fixture corpus
/// (`Fixtures/destination-corpus.txt`), each under a top-level `Bestand NN`, and a dated receipts tree `Belege` with a
/// year, month and a few day folders for 2031–2039. Nothing in it is new invented data: the copies reuse the fixture's
/// names and the receipts tree is generic words and numbers.
///
/// About 25,000 folders in Finder order (parents before children); the fixture's decomposed (NFD) paths stay
/// decomposed.
func largeArchiveCorpus() -> [String] {
  let corpus = fixtureCorpus()
  var paths: [String] = []
  for copy in 1...largeArchiveCopyCount {
    let copyFolder = largeArchiveCopyFolder(copy)
    paths.append(copyFolder)
    paths += corpus.map { "\(copyFolder)/\($0)" }
  }
  paths.append("Belege")
  for year in 2031...2039 {
    paths.append("Belege/\(year)")
    for month in 1...12 {
      let monthFolder = "Belege/\(year)/\(year)-\(twoDigits(month))"
      paths.append(monthFolder)
      for day in stride(from: 3, through: 28, by: 5) {
        paths.append(
          "\(monthFolder)/\(year)-\(twoDigits(month))-\(twoDigits(day)) Beleg \(day * 7)")
      }
    }
  }
  return paths
}

/// How many copies of the fixture corpus ``largeArchiveCorpus()`` holds.
let largeArchiveCopyCount = 60

/// The top-level folder of copy `copy` (1-based) in ``largeArchiveCorpus()``.
func largeArchiveCopyFolder(_ copy: Int) -> String {
  "Bestand \(twoDigits(copy))"
}

private func twoDigits(_ number: Int) -> String {
  number < 10 ? "0\(number)" : "\(number)"
}
