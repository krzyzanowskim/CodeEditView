extension String {

    /// Chunks of lines.
    /// example: "aaa\nbbb\r\nccc" => "aaa\n","\r\n","ccc"
    func chunksOfLines() -> [Self.SubSequence] {
        chunked {
            !(
                ($0.isNewline && !$1.isNewline) || ($0.isNewline && $1.isNewline) && !($0 == "\r" && $1 == "\n")
            )
        }
    }
}
