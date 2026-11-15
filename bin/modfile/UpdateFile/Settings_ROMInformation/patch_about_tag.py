#!/usr/bin/env python3
import os, re, sys

def patch_about_tag(resroot):
    """Inject 'Error OS 1.1 | @NVT-Master' TextView into miui_version_card.xml.
       Uses inline literal text, NO new resource symbols (no @+id / @string),
       so the decoded resource table stays byte-identical except for this edit."""
    layout = resroot + '/layout/miui_version_card.xml'
    if not os.path.isfile(layout):
        print('warn: miui_version_card.xml not found in', resroot)
        return 1

    xml = open(layout, encoding='utf-8').read()
    if 'android:text="Error OS 1.1 | @NVT-Master"' in xml:
        print('tag already injected in', layout)
        return 0

    new_tv = (
        '    <TextView android:textSize="12.0sp"\n'
        '              android:textColor="#FFFFFF"\n'
        '              android:scrollbars="none"\n'
        '              android:fadingEdge="none"\n'
        '              android:layout_width="wrap_content"\n'
        '              android:layout_height="wrap_content"\n'
        '              android:layout_marginTop="4.0dp"\n'
        '              android:paddingLeft="8.0dp"\n'
        '              android:paddingRight="8.0dp"\n'
        '              android:paddingTop="2.0dp"\n'
        '              android:paddingBottom="2.0dp"\n'
        '              android:includeFontPadding="false"\n'
        '              android:importantForAccessibility="no"\n'
        '              android:text="Error OS 1.1 | @NVT-Master" />\n'
    )
    m = re.search(r'(</LinearLayout>)', xml)
    if not m:
        print('warn: no </LinearLayout> in', layout)
        return 1
    newxml = xml[:m.start()] + new_tv + xml[m.start():]
    open(layout, 'w', encoding='utf-8').write(newxml)
    print('patched', layout)
    return 0

if __name__ == '__main__':
    resroot = sys.argv[1] if len(sys.argv) > 1 else None
    if not resroot or not os.path.isdir(resroot):
        print('usage: patch_about_tag.py <resroot>')
        sys.exit(2)
    sys.exit(patch_about_tag(resroot))
