#
# radiobutton widget demo (called by 'widget')
#

# toplevel widget が存在すれば削除する
if defined?($radio_demo) && $radio_demo
  $radio_demo.destroy 
  $radio_demo = nil
end

# demo 用の toplevel widget を生成
$radio_demo = TkToplevel.new {|w|
  title("Radiobutton Demonstration")
  iconname("radio")
  positionWindow(w)
}

# label 生成
msg = TkLabel.new($radio_demo) {
  font $font
  wraplength '4i'
  justify 'left'
  text "下には2つのラジオボタングループが表示されています。ボタンをクリックすると、そのボタンだけがそのグループの中で選択されます。各グループに対してそのグループの中のどのボタンが選択されているかを示す変数が割り当てられています。現在の変数の値を見るには「変数参照」ボタンをクリックしてください。"
}
msg.pack('side'=>'top')

# 変数生成
size = TkVariable.new
color = TkVariable.new

# frame 生成
TkFrame.new($radio_demo) {|frame|
  TkButton.new(frame) {
    text '了解'
    command proc{
      tmppath = $radio_demo
      $radio_demo = nil
      $showVarsWin[tmppath.path] = nil
      tmppath.destroy
    }
  }.pack('side'=>'left', 'expand'=>'yes')

  TkButton.new(frame) {
    text 'コード参照'
    command proc{showCode 'radio'}
  }.pack('side'=>'left', 'expand'=>'yes')

  TkButton.new(frame) {
    text '変数参照'
    command proc{
      showVars($radio_demo, ['size', size], ['color', color])
    }
  }.pack('side'=>'left', 'expand'=>'yes')
}.pack('side'=>'bottom', 'fill'=>'x', 'pady'=>'2m')

# frame 生成
f_left = TkFrame.new($radio_demo)
f_right = TkFrame.new($radio_demo)
f_left.pack('side'=>'left', 'expand'=>'yes', 'padx'=>'.5c', 'pady'=>'.5c')
f_right.pack('side'=>'left', 'expand'=>'yes', 'padx'=>'.5c', 'pady'=>'.5c')

# radiobutton 生成
[10, 12, 18, 24].each {|sz|
  TkRadioButton.new(f_left) {
    text "ポイントサイズ #{sz}"
    variable size
    relief 'flat'
    value sz
  }.pack('side'=>'top', 'pady'=>2, 'anchor'=>'w')
}

['赤', '緑', '青', '黄', '橙', '紫'].each {|col|
  TkRadioButton.new(f_right) {
    text col
    variable color
    relief 'flat'
    value col.downcase
  }.pack('side'=>'top', 'pady'=>2, 'anchor'=>'w')
}

