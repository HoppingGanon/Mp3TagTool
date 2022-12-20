. "${PSScriptRoot}\..\lib\ConsoleSelector\ConsoleSelector.ps1"

$_ExapmleLen = 5
$LogPath1 = "${PSScriptRoot}\..\FileData.log"
$LogPath2 = "${PSScriptRoot}\..\convert.log"

# ���������s����֐�
function Show () {
    $sel = Show-Console-FilePicker -Title 'Mp3TagTool' -Help -Folder
    if ($sel.Code -ne 0) {
        # �I��
        return
    }
    $path = $sel.Path

    $delm = ''
    $Header = "�t�@�C������t�H���_���̐擪�ɂ��鐔���ꍇ�A���̐����������܂����H`n" + `
        "�t�@�C�����̐擪�ɐ��������Ă�ꍇ�̓g���b�N�ԍ��ɐݒ肵�܂��B`n" + `
        "  <��>`n  01.����.mp3 -> ����"
    $sel = Show-Console-Selector -Title 'Mp3TagTool' -Header $Header -Help -Model @('�͂�','������')
    if ($sel -ne 1) {
        $delms = @(
            @{delm='.';disp='. (�h�b�g)'},
            @{delm='_';disp='_ (�A���_�[�X�R�A)'},
            @{delm='-';disp='- (�n�C�t��)'},
            @{delm=' ';disp='  (�X�y�[�X)'},
            @{delm='+';disp='+ (�v���X)'}
        )
        $sel = Show-Console-Selector -Title 'Mp3TagTool' -Header "��؂蕶����I�����Ă�������" -model $delms.disp
        if ($sel -lt 0 -or $sel -eq $null) {
            # �I��
            return
        }
        $delm = $delms[$sel].delm
    }
    
    $list = Analyze-Folder -Delimiter $delm -ParentDir $path
    $list | ConvertTo-Json > $LogPath1
    $maxDepth = ($list | ?{-not $_.IsContainer} | measure -Maximum -Property Depth).Maximum - 1

    if ($list.Count -eq 0) {
        Show-Console-Message -Title 'Mp3TagTool' -Message "MP3�t�@�C����������܂���ł����B"
        return
    }

    $sel = Show-Console-Selector -Title 'Mp3TagTool' -Header "$(($list | ?{$_.extension -eq '.mp3'}).Count)��MP3�t�@�C����������܂����B`n���^�O�������ݒ肵�܂����H" -Help -Model @('�͂�','������')
    if ($sel -ne 0) {
        # �u�͂��v�ȊO�I��
        return
    }

    # �ҏW�^�O���X�g
    $tagList = @(
        @{
            Name='artist'
            Disp='�A�[�e�B�X�g'
        },
        @{
            Name='album'
            Disp='�A���o��'
        },
        @{
            Name='date'
            Disp='�����[�X�N'
        },
        @{
            Name='genre'
            Disp='�W������'
        },
        @{
            Name='comment'
            Disp='�R�����g'
        },
        @{
            Name='None'
            Disp='�g�p���Ȃ�'
        }
    )

    $tagSelList = New-Object System.Collections.Hashtable[] ($maxDepth + 1)

    $state = 0
    while ($state -le $maxDepth) {
        # ����擾
        $example = New-Object Text.StringBuilder
        $example.Append("  <�t�H���_��>`n") | Out-Null
        $i=0
        :lo foreach ($item in ($list | ?{$_.IsContainer -and $_.Depth -eq $state})) {
            if ($i -ge $_ExapmleLen) {
                $example.Append("      ...`n") | Out-Null
                break lo
            }
            $example.Append("    - $($item.Name)`n") | Out-Null
            $i++
        }

        #���b�Z�[�W���쐬
        $message = "�t�H���_���̑�${state}�K�w��MP3�̃^�O�ɖ��ߍ��݂܂��B`n" + `
            '�t�H���_���ƑΉ�����^�O��I��ł��������B'

        $tagsel = Show-Console-Selector -Title 'Mp3TagTool' -Header $Message -Model $tagList.Disp -Footer $example.ToString()
        switch ($tagsel) {
            $null {
                # �G���[
                return
            }
            -2 {
                # �I��
                return
            }
            -1 {
                # �߂�
                if ($state -eq 0) {
                    return
                } else {
                    $state--
                }
                break
            }
            default {
                # �^�O��I�������ꍇ
                if ($sel -eq 5) {
                    $tagSelList[$state] = $null
                } else {
                    $tagSelList[$state] = $tagList[$tagsel]
                }
                $state++
            }
        }
    }

    $sel = Show-Console-Selector -Title 'Mp3TagTool' -Header "�{���Ƀ^�O��ݒ肵�܂����H" -Help -Model @('�͂�','������')
    if ($sel -ne 0) {
        # �u�͂��v�ȊO�I��
        return
    }
    
    echo '�ϊ��J�n' > $LogPath2
    echo (Get-Date).ToString() >> $LogPath2
    echo $tagSelList >> $LogPath2
    
    # ���̃t�@�C���Ɠ������̂̃t�@�C������������_�������ǂ����܂ł̗�O�����͂��Ȃ�
    $tempFileName = '__tmp_ffmpeg_mp3_tags_tool__.mp3'
    $sb = New-Object Text.StringBuilder

    $fileList = $list | ?{-not $_.IsContainer -and $_}
    $tick = 0
    :loconv foreach ($item in $fileList) {
        if ($tick % 16 -eq 0) {
            cls
            Show-Console-Message -Title 'Mp3TagTool' -Message "�t�@�C����: ${tick} / $($fileList.Count)`n�i����: $((100.0 * $tick / $fileList.Count).ToString('0.0'))%"
        }
        # ���Ƀt�H���_�����݂��Ă�����폜
        try {
            if ((Test-Path "$($item.Directory)\\${tempFileName}" -PathType Container)) {
                echo "'$($item.Directory)\\${tempFileName}'���폜���܂�" >> $LogPath2
                rmdir "$($item.Directory)\\${tempFileName}" -Force
            }
        } catch {
            "'$($item.Directory)'�ɍ�Ɨp�t�@�C���Ɠ����̃t�H���_�����邽�߁A�t�@�C���𐶐��ł��܂���" >> $LogPath2
            Write-Host "'$($item.Directory)'�ɍ�Ɨp�t�@�C���Ɠ����̃t�H���_�����邽�߁A�t�@�C���������s" -ForegroundColor Yellow
            return
        }

        $sb.clear() | Out-Null
        $sb.Append('ffmpeg.exe -hide_banner -i "').Append($item.FullPath).Append('" -codec copy') | Out-Null

        for ($i=0;$i -lt $item.Parent.Count; $i++) {
            # ���^�f�[�^����������
            if ($tagSelList[$i].Name -ne 'None') {
                $sb.Append(" -metadata $($tagSelList[$i].Name)=`"$($item.Parent[$i])`"") | Out-Null
            }
        }
        # �g���b�N�ԍ�
        if ($item.Number -ge 0) {
            $sb.Append(" -metadata track=`"$($item.Number)`"") | Out-Null
        }
        # �^�C�g��
        $sb.Append(" -metadata title=`"$($item.Name)`"") | Out-Null

        $sb.Append(" -codec copy -y `"$($item.Directory)\\${tempFileName}`"") | Out-Null

        # ffmpeg�̎��s
        $command = $sb.ToString()
        echo 'ffmpeg�R�}���h���s' >> $LogPath2
        echo $command >> $LogPath2
        echo '' >> $LogPath2
        Invoke-Expression $command 2>&1 > $null

        if (-not (Test-Path "$($item.Directory)\\${tempFileName}" -PathType Leaf)) {
            echo "'$($item.FullPath)'�̕ϊ����������s" >> $LogPath2
            Write-Host "'$($item.FullPath)'�̕ϊ����������s���܂����B" -ForegroundColor Yellow
            return
        }

        # �t�@�C����u��
        try {
            # �X�V�����������܂���
            $oldfile = Get-Item $item.FullPath
            $LastAccessTime = $oldfile.LastAccessTime
            $LastWriteTime = $oldfile.LastWriteTime
            $CreationTime = $oldfile.CreationTime

            # �t�@�C���̈ړ�
            echo "'$($item.Directory)\\${tempFileName}'��'$($item.FullPath)'�̓���ւ������s" >> $LogPath2
            rm $item.FullPath -force
            mv "$($item.Directory)\\${tempFileName}" $item.FullPath

            # �X�V�����������܂���
            echo "'$($item.FullPath)'�̍X�V���������܂��������s" >> $LogPath2
            $newfile = Get-Item $item.FullPath
            $newfile.LastAccessTime = $LastAccessTime
            $newfile.LastWriteTime = $LastWriteTime
            $newfile.CreationTime = $CreationTime
        } catch {
            echo "'$($item.FullPath)'�̍�ƒ��ɏ��������s" >> $LogPath2
            Write-Host "'$($item.FullPath)'�̍�ƒ��ɏ��������s���܂����B" -ForegroundColor Yellow
            Write-Host $error[0].Exception -ForegroundColor Yellow
            return
        }
        echo '' >> $LogPath2
        $tick++
    }
    cls
    Show-Console-Message -Title 'Mp3TagTool' -Message "�t�@�C����: $($fileList.Count) / $($fileList.Count)`n�i����: 100.0%`n�������������܂����B"
    echo '�ϊ�����' >> $LogPath2
    echo (Get-Date).ToString() >> $LogPath2
}

# �t�H���_���̏������W����N�_�ƂȂ�֐�
function Analyze-Folder ($ParentDir = '', [String]$Delimiter = '') {
    if ($ParentDir -eq '') {
        $ParentDir = (pwd).Path
    }
    
    $list = (New-Object Collections.ArrayList)
    $plist = (New-Object Collections.ArrayList)

    # �ŏ��̊K�w��ǉ�
    $pfol = Get-Item $ParentDir
    $nameObj = Fix-Name $pfol.Name $Delimiter
    $plist.Add($nameObj.Name) | Out-Null
    $info = Make-Info $nameObj.Name $nameObj.Number $Extension $true 0 $pfol.FullName $pfol.Directory $plist
    $list.Add($info) | Out-Null

    Analyze-Folder-Recurse -Path $ParentDir -List $list -Delimiter $Delimiter -Depth 1 -Parent $plist | Out-Null
    $maxDepth = ($list | measure -Maximum -Property Depth).Maximum
    
    return $list
}

# �ċA�I�Ƀt�H���_���̏������W����֐�
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

# �t�@�C���̏����������I�u�W�F�N�g�𐶐�����֐�
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

# �擪�̔ԍ��Ɩ��O�𕪗�����֐�
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
