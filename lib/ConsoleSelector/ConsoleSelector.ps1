function Show-Console-Message ([String]$Header = '', [String]$Message = '', [String]$Footer = '',[String]$Title = '') {
<#
    .SYNOPSIS
        Show-Console-Selectorのテーマに合わせたメッセージを表示できるコマンドレットです。
        選択肢が必要ない場合などに利用してください。
    .DESCRIPTION
        
    .PARAMETER Header
        選択肢の上部に表示するメッセージです。
    .PARAMETER Message
        主文として表示する文字列です。
    .PARAMETER Footer
        選択肢の下部に表示するメッセージです。
    .PARAMETER Title
        上部に表記するタイトルです。省略するとタイトルバーは表示しません。

    .OUTPUTS
        なし

    .EXAMPLE 
        Show-Console-Selector -Title 'テスト' -Header 'メッセージ' -Message 'これはテストです'

        テスト
        ----------------------------------------------------------

        メッセージ

        これはテストです
#>
    cls

    if ($Title -ne '') {
        Write-Host $title -ForegroundColor Yellow
        Write-Host '----------------------------------------------------------'
        Write-Host ''
    }

    if ($Header -ne '') {
        Write-Host $Header
        Write-Host ''
    }

    if ($Message -ne '') {
        Write-Host $Message
        Write-Host ''
    }
            
    if ($Footer -ne '') {
        Write-Host ''
        Write-Host $Footer
    }
}




function Show-Console-Selector ([String]$Header = '', [String[]]$Model = @(), [String]$Footer = '',[String]$Title = '', [switch]$Help = $true, [Int]$Default = 0, [switch]$Mult = $false) {
<#
    .SYNOPSIS
        コンソール上で非常に可視的な選択肢を表示できるコマンドレットです。
        画面は色分けされて表示されます。
    .DESCRIPTION
        
    .PARAMETER Header
        選択肢の上部に表示するメッセージです。
    .PARAMETER Model
        選択肢として表示する文字列です。文字列配列を指定してください。
    .PARAMETER Footer
        選択肢の下部に表示するメッセージです。
    .PARAMETER Title
        上部に表記するタイトルです。省略するとタイトルバーは表示しません。
    .PARAMETER Help
        [Switch]指定すると操作方法が下部に表示されます。
    .PARAMETER Default
        初期状態のカーソル位置を設定できます。省略すると一番上に合わせます。
    .PARAMETER Mult
        [Switch]指定すると複数選択が可能になります。

    .OUTPUTS
        結果を表すCodeと選択されたパス(フルパス)を表すPathを持つHashTableを返します。
        Codeの意味は以下の通り
            0 <  選択した選択肢のインデックス番号
            -1   戻るを押下
            -2   終了を押下
            null エラー終了
    .EXAMPLE 
        Show-Console-Selector -Title 'テスト' -Header 'メッセージ' -Model @('はい', 'いいえ')

        テスト
        ----------------------------------------------------------

        メッセージ

          * はい
          * いいえ

        ----------------------------------------------------------
        [↑/↓]カーソル移動 [Enter]決定 [BackSpace]戻る [Esc]終了
#>
    $sel = $Default
    $selAry = New-Object boolean[] $Model.Count
    $warning = ''

    if ($Mult) {
        $i=0
        $selAry | %{
            $selAry[$i] = $false
            $i++
        }
    }

    try {
        while ($true) {
            cls

            if ($Title -ne '') {
                Write-Host $title -ForegroundColor Yellow
                Write-Host '----------------------------------------------------------'
                Write-Host ''
            }

            if ($Header -ne '') {
                Write-Host $Header
                Write-Host ''
            }

            $i = 0
            if ($Mult) {
                $Model | %{
                    if ($selAry[$i]) {
                        Write-Host '  * ' -NoNewline -ForegroundColor Cyan
                    } else {
                        Write-Host '  - ' -NoNewline -ForegroundColor Gray
                    }
                    
                    if ($sel -eq $i) {
                        Write-Host "$_" -BackgroundColor White -ForegroundColor Red
                    } else {
                        if ($selAry[$i]) {
                            Write-Host "$_" -ForegroundColor Cyan
                        } else {
                            Write-Host "$_" -ForegroundColor Gray
                        }
                    }
                    $i++
                }
            } else {
                $Model | %{
                    Write-Host '  * ' -NoNewline
                    if ($sel -eq $i) {
                        Write-Host "$_" -BackgroundColor White -ForegroundColor Red
                    } else {
                        Write-Host "$_" -ForegroundColor Cyan
                    }
                    $i++
                }
            }
            

            if ($Footer -ne '') {
                Write-Host ''
                Write-Host $Footer
            }
            
            if ($Help) {
                Write-Host ''
                if ($Mult) {
                    Write-Host '--------------------------------------------------------------------------'
                } else {
                    Write-Host '----------------------------------------------------------'
                }
                Write-Host '[↑/↓]' -ForegroundColor Green -NoNewline
                Write-Host 'カーソル移動 ' -NoNewline
                if ($Mult) {
                    Write-Host '[Space]' -ForegroundColor Green -NoNewline
                    Write-Host '選択/解除 ' -NoNewline
                }
                Write-Host '[Enter]' -ForegroundColor Green -NoNewline
                Write-Host '決定 ' -NoNewline
                Write-Host '[BackSpace]' -ForegroundColor Green -NoNewline
                Write-Host '戻る ' -NoNewline
                Write-Host '[Esc]' -ForegroundColor Green -NoNewline
                Write-Host '終了'
            }
            if ($warning -ne '') {
                Write-Host $warning -ForegroundColor red
            }

            $c = [Console]::ReadKey($true)
            
            switch ($c.Key)
            {
                ([ConsoleKey]::LeftArrow) {
                    
                }
                ([ConsoleKey]::RightArrow){
                    
                }
                ([ConsoleKey]::UpArrow){
                    $sel--
                    if ($sel -lt 0) {
                        $sel = $Model.Count - 1
                    }
                }
                ([ConsoleKey]::DownArrow){
                    $sel++
                    if ($Model.Count -le $sel) {
                        $sel = 0
                    }
                }
                ([ConsoleKey]::Spacebar){
                    $selAry[$sel] = (-not $selAry[$sel])
                }
                ([ConsoleKey]::Enter){
                    if ($Mult) {
                        $cnt = 0
                        $selAry | %{
                            if ($_) {
                                $cnt++
                            }
                        }
                        if ($cnt -eq 0) {
                            $warning = '[Space]キーを押して、一つ以上のアイテムを選択してください。'
                        } else {
                            return $selAry
                        }
                    } else {
                        return $sel
                    }
                    
                }
                ([ConsoleKey]::Backspace) {
                    return -1
                }
                ([ConsoleKey]::Escape) {
                    return -2
                }
            }
        }
    } catch {
        $Error[0].Exception | oh
    }
    
    return $null
}

function Show-Console-FilePicker ([String]$Path = '', [String]$Title = '', [switch]$Help = $true, [Switch]$Folder = $false, [Array]$Extension = @('*.*')) {
<#
    .SYNOPSIS
        コンソール上でファイルやフォルダを選択できる表示を行うコマンドレットです。
    .DESCRIPTION
        
    .PARAMETER Path
        初期表示するフォルダのパスです。省略するとカレントパスを開きます。
    .PARAMETER Title
        上部に表記するタイトルです。省略するとタイトルバーは表示しません。
    .PARAMETER Help
        [Switch]指定すると操作方法が下部に表示されます
    .PARAMETER Folder
        [Switch]指定するとフォルダのみ選択できるようになります。指定しない場合はファイルのみ選択できるようになります。
    .PARAMETER Extension
        選択可能なファイル名をワイルドカードで指定します。

    .OUTPUTS
        結果を表すCodeと選択されたパス(フルパス)を表すPathを持つHashTableを返します。
        Codeの意味は以下の通り
            0    正常選択
            -1   戻るを押下したことによる終了
            -2   終了を押下したことによる終了
            null エラー終了
    .EXAMPLE 
        Show-Console-FilePicker (".\") -Folder

        ...

        Name                           Value
        ----                           -----
        Code                           0
        Path                           {D:\Develop\}
#>
    if ($Path -eq '') {
        $Path = (pwd).Path
    }

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw '指定したパスにアクセスできません'
    }
    while ($true) {

        # パスをフルパスに変更
        $Path = (Get-Item -Path $Path).FullName

        # ファイやフォルダの情報
        $list = New-Object Collections.ArrayList

        # フォルダ操作ボタン追加
        $list.Add(@{Disp='【 *ひとつ上の親フォルダ* 】'}) | Out-Null
        
        # フォルダの追加
        ls $Path | ?{$_.PSIsContainer} | %{
            $list.Add(@{Name=$_.FullName;Disp=" [Folder] $($_.Name)";Folder=$true}) | Out-Null
        }
        
        if (-not $Folder) {
            # ファイルの追加
            $Footer = "選択可能なファイル形式 ${Extension}"
            ls $Path | ?{-not $_.PSIsContainer -and $_.BaseName -like $Extension} | %{
                $list.Add(@{Name=$_.FullName;Disp="          $($_.Name)";Folder=$false}) | Out-Null
            }
            $header = 'ファイルを選んでください'
        } elseif ($Folder) {
            # フォルダを開くボタンを追加
            $Footer = '対象のフォルダを表示した状態で【 *フォルダを開く* 】を選択してください'
            $list.Add(@{Disp='【 *このフォルダを開く* 】'}) | Out-Null
            $header = 'フォルダを選んでください'
        }
        $header += "`n現在のパス: $($Path)"

        # 画面表示
        $sel = Show-Console-Selector `
            -Header $header `
            -Footer $Footer `
            -Model $list.Disp `
            -Title $Title `
            -Help $Help `
            -Default 1

        # 結果処理
        if ($sel -eq -2) {
            # 終了
            return @{
                Code=$sel
                Path=@()
            }
        } elseif ($sel -eq -1) {
            # 戻る
            return @{
                Code=$sel
                Path=@()
            }
        } elseif ($sel -eq $null) {
            # Error
            return @{
                Code=$sel
                Path=@()
            }
        } elseif ($Folder -and $sel -eq $list.Count - 1) {
            # 開くボタン
            return @{
                Code=0
                Path=@($Path)
            }
        } elseif ($sel -eq 0) {
            # 上のフォルダ
            $this = Get-Item $Path
            $rtn = Show-Console-FilePicker -Path $this.Parent.FullName -Title $Title -Help $Help -Folder $Folder -Extension $Extension
            if ($rtn.Code -eq 0 -or $rtn.Code -eq -2 -or $rtn.Code -eq $null) {
                # 再帰的に終了
                return $rtn
            }
        } elseif ($Folder -and $sel -eq $list.Count - 1) {
            return @{
                Code=0
                Path=@($Path)
            }
        } else {
            # ファイルやフォルダを選択
            if ($list[$sel].Folder) {
                # フォルダ選択
                $rtn = Show-Console-FilePicker -Path $list[$sel].Name -Title $Title -Help $Help -Folder $Folder -Extension $Extension
                if ($rtn.Code -eq 0 -or $rtn.Code -eq -2 -or $rtn.Code -eq $null) {
                    # 再帰的に終了
                    return $rtn
                }
            } elseif (-not $Folder) {
                # ファイル選択
                return @{
                    Code=0
                    Path=@($list[$sel].Name)
                }
            }
        }
    }
}
