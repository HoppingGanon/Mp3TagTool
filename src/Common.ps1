. "${PSScriptRoot}\..\lib\ConsoleSelector\ConsoleSelector.ps1"

$_ExapmleLen = 5
$LogPath1 = "${PSScriptRoot}\..\FileData.log"
$LogPath2 = "${PSScriptRoot}\..\convert.log"

# 処理を実行する関数
function Show () {
    $sel = Show-Console-FilePicker -Title 'Mp3TagTool' -Help -Folder
    if ($sel.Code -ne 0) {
        # 終了
        return
    }
    $path = $sel.Path

    $delm = ''
    $Header = "ファイル名やフォルダ名の先頭にある数字場合、その数字除去しますか？`n" + `
        "ファイル名の先頭に数字がついてる場合はトラック番号に設定します。`n" + `
        "  <例>`n  01.序曲.mp3 -> 序曲"
    $sel = Show-Console-Selector -Title 'Mp3TagTool' -Header $Header -Help -Model @('はい','いいえ')
    if ($sel -ne 1) {
        $delms = @(
            @{delm='.';disp='. (ドット)'},
            @{delm='_';disp='_ (アンダースコア)'},
            @{delm='-';disp='- (ハイフン)'},
            @{delm=' ';disp='  (スペース)'},
            @{delm='+';disp='+ (プラス)'}
        )
        $sel = Show-Console-Selector -Title 'Mp3TagTool' -Header "区切り文字を選択してください" -model $delms.disp
        if ($sel -lt 0 -or $sel -eq $null) {
            # 終了
            return
        }
        $delm = $delms[$sel].delm
    }
    
    $list = Analyze-Folder -Delimiter $delm -ParentDir $path
    $list | ConvertTo-Json > $LogPath1
    $maxDepth = ($list | ?{-not $_.IsContainer} | measure -Maximum -Property Depth).Maximum - 1

    if ($list.Count -eq 0) {
        Show-Console-Message -Title 'Mp3TagTool' -Message "MP3ファイルが見つかりませんでした。"
        return
    }

    $sel = Show-Console-Selector -Title 'Mp3TagTool' -Header "$(($list | ?{$_.extension -eq '.mp3'}).Count)個のMP3ファイルが見つかりました。`n情報タグを自動設定しますか？" -Help -Model @('はい','いいえ')
    if ($sel -ne 0) {
        # 「はい」以外終了
        return
    }

    # 編集タグリスト
    $tagList = @(
        @{
            Name='artist'
            Disp='アーティスト'
        },
        @{
            Name='album'
            Disp='アルバム'
        },
        @{
            Name='date'
            Disp='リリース年'
        },
        @{
            Name='genre'
            Disp='ジャンル'
        },
        @{
            Name='comment'
            Disp='コメント'
        },
        @{
            Name='None'
            Disp='使用しない'
        }
    )

    $tagSelList = New-Object System.Collections.Hashtable[] ($maxDepth + 1)

    $state = 0
    while ($state -le $maxDepth) {
        # 例を取得
        $example = New-Object Text.StringBuilder
        $example.Append("  <フォルダ名>`n") | Out-Null
        $i=0
        :lo foreach ($item in ($list | ?{$_.IsContainer -and $_.Depth -eq $state})) {
            if ($i -ge $_ExapmleLen) {
                $example.Append("      ...`n") | Out-Null
                break lo
            }
            $example.Append("    - $($item.Name)`n") | Out-Null
            $i++
        }

        #メッセージを作成
        $message = "フォルダ名の第${state}階層をMP3のタグに埋め込みます。`n" + `
            'フォルダ名と対応するタグを選んでください。'

        $tagsel = Show-Console-Selector -Title 'Mp3TagTool' -Header $Message -Model $tagList.Disp -Footer $example.ToString()
        switch ($tagsel) {
            $null {
                # エラー
                return
            }
            -2 {
                # 終了
                return
            }
            -1 {
                # 戻る
                if ($state -eq 0) {
                    return
                } else {
                    $state--
                }
                break
            }
            default {
                # タグを選択した場合
                if ($sel -eq 5) {
                    $tagSelList[$state] = $null
                } else {
                    $tagSelList[$state] = $tagList[$tagsel]
                }
                $state++
            }
        }
    }

    $sel = Show-Console-Selector -Title 'Mp3TagTool' -Header "本当にタグを設定しますか？" -Help -Model @('はい','いいえ')
    if ($sel -ne 0) {
        # 「はい」以外終了
        return
    }
    
    echo '変換開始' > $LogPath2
    echo (Get-Date).ToString() >> $LogPath2
    echo $tagSelList >> $LogPath2
    
    # このファイルと同じ名称のファイルがあったらダメだけどそこまでの例外処理はしない
    $tempFileName = '__tmp_ffmpeg_mp3_tags_tool__.mp3'
    $sb = New-Object Text.StringBuilder

    $fileList = $list | ?{-not $_.IsContainer -and $_}
    $tick = 0
    :loconv foreach ($item in $fileList) {
        if ($tick % 16 -eq 0) {
            cls
            Show-Console-Message -Title 'Mp3TagTool' -Message "ファイル数: ${tick} / $($fileList.Count)`n進捗率: $((100.0 * $tick / $fileList.Count).ToString('0.0'))%"
        }
        # 既にフォルダが存在していたら削除
        try {
            if ((Test-Path "$($item.Directory)\\${tempFileName}" -PathType Container)) {
                echo "'$($item.Directory)\\${tempFileName}'を削除します" >> $LogPath2
                rmdir "$($item.Directory)\\${tempFileName}" -Force
            }
        } catch {
            "'$($item.Directory)'に作業用ファイルと同名のフォルダがあるため、ファイルを生成できません" >> $LogPath2
            Write-Host "'$($item.Directory)'に作業用ファイルと同名のフォルダがあるため、ファイル生成失敗" -ForegroundColor Yellow
            return
        }

        $sb.clear() | Out-Null
        $sb.Append('ffmpeg.exe -hide_banner -i "').Append($item.FullPath).Append('" -codec copy') | Out-Null

        for ($i=0;$i -lt $item.Parent.Count; $i++) {
            # メタデータを書き込む
            if ($tagSelList[$i].Name -ne 'None') {
                $sb.Append(" -metadata $($tagSelList[$i].Name)=`"$($item.Parent[$i])`"") | Out-Null
            }
        }
        # トラック番号
        if ($item.Number -ge 0) {
            $sb.Append(" -metadata track=`"$($item.Number)`"") | Out-Null
        }
        # タイトル
        $sb.Append(" -metadata title=`"$($item.Name)`"") | Out-Null

        $sb.Append(" -codec copy -y `"$($item.Directory)\\${tempFileName}`"") | Out-Null

        # ffmpegの実行
        $command = $sb.ToString()
        echo 'ffmpegコマンド実行' >> $LogPath2
        echo $command >> $LogPath2
        echo '' >> $LogPath2
        Invoke-Expression $command 2>&1 > $null

        if (-not (Test-Path "$($item.Directory)\\${tempFileName}" -PathType Leaf)) {
            echo "'$($item.FullPath)'の変換処理が失敗" >> $LogPath2
            Write-Host "'$($item.FullPath)'の変換処理が失敗しました。" -ForegroundColor Yellow
            return
        }

        # ファイルを置換
        try {
            # 更新日時等をごまかす
            $oldfile = Get-Item $item.FullPath
            $LastAccessTime = $oldfile.LastAccessTime
            $LastWriteTime = $oldfile.LastWriteTime
            $CreationTime = $oldfile.CreationTime

            # ファイルの移動
            echo "'$($item.Directory)\\${tempFileName}'と'$($item.FullPath)'の入れ替えを実行" >> $LogPath2
            rm $item.FullPath -force
            mv "$($item.Directory)\\${tempFileName}" $item.FullPath

            # 更新日時等をごまかす
            echo "'$($item.FullPath)'の更新日時等ごまかしを実行" >> $LogPath2
            $newfile = Get-Item $item.FullPath
            $newfile.LastAccessTime = $LastAccessTime
            $newfile.LastWriteTime = $LastWriteTime
            $newfile.CreationTime = $CreationTime
        } catch {
            echo "'$($item.FullPath)'の作業中に処理が失敗" >> $LogPath2
            Write-Host "'$($item.FullPath)'の作業中に処理が失敗しました。" -ForegroundColor Yellow
            Write-Host $error[0].Exception -ForegroundColor Yellow
            return
        }
        echo '' >> $LogPath2
        $tick++
    }
    cls
    Show-Console-Message -Title 'Mp3TagTool' -Message "ファイル数: $($fileList.Count) / $($fileList.Count)`n進捗率: 100.0%`n処理が完了しました。"
    echo '変換完了' >> $LogPath2
    echo (Get-Date).ToString() >> $LogPath2
}

# フォルダ内の情報を収集する起点となる関数
function Analyze-Folder ($ParentDir = '', [String]$Delimiter = '') {
    if ($ParentDir -eq '') {
        $ParentDir = (pwd).Path
    }
    
    $list = (New-Object Collections.ArrayList)
    $plist = (New-Object Collections.ArrayList)

    # 最初の階層を追加
    $pfol = Get-Item $ParentDir
    $nameObj = Fix-Name $pfol.Name $Delimiter
    $plist.Add($nameObj.Name) | Out-Null
    $info = Make-Info $nameObj.Name $nameObj.Number $Extension $true 0 $pfol.FullName $pfol.Directory $plist
    $list.Add($info) | Out-Null

    Analyze-Folder-Recurse -Path $ParentDir -List $list -Delimiter $Delimiter -Depth 1 -Parent $plist | Out-Null
    $maxDepth = ($list | measure -Maximum -Property Depth).Maximum
    
    return $list
}

# 再帰的にフォルダ内の情報を収集する関数
function Analyze-Folder-Recurse ([String]$Path, [Collections.ArrayList]$List, [String]$Delimiter, [Int]$Depth, [Collections.ArrayList]$Parent) {
    ls $Path | %{
        $f = $_
        if ($f.PSIsContainer) {
            $nameObj = Fix-Name $f.Name $Delimiter
            $info = Make-Info $nameObj.Name $nameObj.Number '' $true $Depth $f.FullName $f.Directory $Parent
            $List.Add($info) | Out-Null
            $parentClone = $Parent.Clone()
            $parentClone.Add($nameObj.Name) | Out-Null
            Analyze-Folder-Recurse -Path $f.FullName -List $List -Delimiter $Delimiter -Depth ($Depth + 1) -Parent $parentClone | Out-Null
        } elseif ($f.Extension -eq '.mp3') {
            $nameObj = Fix-Name $f.BaseName $Delimiter
            $info = Make-Info $nameObj.Name $nameObj.Number $f.Extension $false $Depth $f.FullName $f.Directory $Parent
            $List.Add($info) | Out-Null
        }
    }
}

# ファイルの情報を持ったオブジェクトを生成する関数
function Make-Info ([String]$Name, [Int]$Number,[String]$Extension, [Boolean]$IsContainer, [Int]$Depth, [String]$FullPath, [String]$Directory, [Collections.ArrayList]$Parent) {
    return New-Object PSCustomObject -Property @{
        Name = $Name
        Number = $Number
        Extension = $Extension
        IsContainer = $IsContainer
        Depth = $Depth
        FullPath = $FullPath
        Parent = $Parent
        Directory = $Directory
    }
}

# 先頭の番号と名前を分離する関数
function Fix-Name ([String]$text, [String]$Delimiter) {
    if ($Delimiter -ne '' -and $text -match '^[0-9]*\.') {
        $pl = $text.IndexOf($Delimiter)
        
        return New-Object PSCustomObject -Property @{
            Name = $text.Substring($pl + 1,$text.Length - $pl - 1)
            Number = [Int]($text.Substring(0,$pl))
        }
    } else {
        return New-Object PSCustomObject -Property @{
            Name = $text
            Number = -1
        }
    }
}
