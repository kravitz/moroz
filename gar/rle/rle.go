package rle

import (
    "os"
    "gob"
    "fmt"
    "bufio"
)

import . "common"

type (
    rleMeta struct {
        Size int64
    }
)


func Compress(fin *os.File, fout *os.File) {
    var curr, prev, count byte = 0, 0, 0
    found := false
    var error os.Error = nil

    PanicIf(gob.NewEncoder(fout).Encode(rleMeta{GetFileSize(fin)}))
    in := bufio.NewReader(fin)
    out := bufio.NewWriter(fout)
    defer out.Flush()

    for {
        curr, error = in.ReadByte()
        if error != nil {
            break
        }
        if found {
            if curr == prev && count < 255 {
                count++
            } else {
                out.WriteByte(count)
                out.WriteByte(curr)
                count = 0
                found = false
            }
        } else {
            out.WriteByte(curr)
            found = curr == prev
        }
        prev = curr
    }
    if count > 0 {
        out.WriteByte(count)
    }
}

func Extract(fin *os.File, fout *os.File) (readBytes int64) {
    var (
        curr, prev byte = 0, 0
        found, valid_prev bool = false, true
        error os.Error = nil
        cursize int64 = 0
    )
    var rmeta rleMeta
    PanicIf(gob.NewDecoder(fin).Decode(&rmeta))
    fmt.Print("pan")
    in := bufio.NewReader(fin)
    out := bufio.NewWriter(fout)
    defer out.Flush()
    readBytes = 0
    for cursize < rmeta.Size {
        curr, error = in.ReadByte()
        if error != nil {
            if found {
                panic("Archive corrupted")
            }
            break
        }
        readBytes++
        if found {
            cursize += int64(curr)
            for ; curr > 0; curr-- {
                out.WriteByte(prev)
            }
            valid_prev = false
            found = false
        } else {
            cursize++
            out.WriteByte(curr)
            found = curr == prev && valid_prev
            prev = curr
            valid_prev = true
        }
    }
    return readBytes
}
