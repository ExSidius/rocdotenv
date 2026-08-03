module [
    Entry,
    Env,
    FakeFile,
    FakeFileSource,
    MarshalErr,
    ParseErr,
    ReadErr,
]

Entry : { key : Str, value : Str }
Env : List Entry
FakeFileSource : [File Str, Directory]
FakeFile : { path : Str, source : FakeFileSource }
ParseErr : [UnexpectedChar, UnterminatedQuote]
MarshalErr : [MarshalFailed]
ReadErr : [FileNotFound Str, IsDirectory Str, UnexpectedChar, UnterminatedQuote]
