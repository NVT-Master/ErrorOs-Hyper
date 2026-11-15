#!/usr/bin/env python3
import os, re, sys

def patch_about_tag(resroot):
    """Inject 'Error OS 1.1 | @NVT-Master' TextView into miui_version_card.xml.
       Add string + public.xml entry idempotently."""
    if not os.path.isfile(resroot + '/layout/miui_version_card.xml'):
        print('warn: miui_version_card.xml not found in', resroot)
        return 1

    # strings.xml + public.xml: idempotent inject
    strings = resroot + '/values/strings.xml'
    sr = resroot + '/values/public.xml'
    if os.path.isfile(strings):
        s = open(strings, encoding='utf-8').read()
        if 'error_os_tag' not in s:
            s = s.replace('</resources>',
                '  <string name="error_os_tag">Error OS 1.1 | @NVT-Master</string>\n</resources>', 1)
            open(strings, 'w', encoding='utf-8').write(s)
    if os.path.isfile(sr):
        s = open(sr, encoding='utf-8').read()
        if 'error_os_tag' not in s:
            s = s.replace('</resources>',
                '  <public id="0x7f153db7" type="string" name="error_os_tag" />\n</resources>', 1)
            open(sr, 'w', encoding='utf-8').write(s)

    # miui_version_card.xml: insert new TextView before </LinearLayout>
    layout = resroot + '/layout/miui_version_card.xml'
    xml = open(layout, encoding='utf-8').read()
    if 'id="@+id/error_os_tag"' in xml or 'android:text="@string/error_os_tag"' in xml:
        print('tags already injected; skipping')
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
        '              android:text="@string/error_os_tag" />\n'
    )
    # find the closing </LinearLayout> of the version_layout block
    m = re.search(r'(</LinearLayout>)', xml)
    if not m:
        print('warn: no </LinearLayout> in miui_version_card.xml')
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
