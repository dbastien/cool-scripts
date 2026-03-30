#include <windows.h>
#include <commdlg.h>

#include <cstdint>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

struct SCNotification;

using PFUNCPLUGINCMD = void(__cdecl *)();

struct NppData {
    HWND _nppHandle = nullptr;
    HWND _scintillaMainHandle = nullptr;
    HWND _scintillaSecondHandle = nullptr;
};

struct ShortcutKey {
    bool _isCtrl = false;
    bool _isAlt = false;
    bool _isShift = false;
    unsigned char _key = 0;
};

constexpr int menuItemSize = 64;

struct FuncItem {
    wchar_t _itemName[menuItemSize] = { L'\0' };
    PFUNCPLUGINCMD _pFunc = nullptr;
    int _cmdID = 0;
    bool _init2Check = false;
    ShortcutKey* _pShKey = nullptr;
};

namespace {
constexpr wchar_t kPluginName[] = L"Unsaved Dump Plugin";
constexpr int kFuncCount = 1;

constexpr UINT NPPMSG = WM_USER + 1000;
constexpr UINT NPPM_GETCURRENTSCINTILLA = NPPMSG + 4;
constexpr UINT NPPM_GETNBOPENFILES = NPPMSG + 7;
constexpr UINT NPPM_ACTIVATEDOC = NPPMSG + 28;
constexpr UINT NPPM_MENUCOMMAND = NPPMSG + 48;
constexpr UINT NPPM_GETPOSFROMBUFFERID = NPPMSG + 57;
constexpr UINT NPPM_GETFULLPATHFROMBUFFERID = NPPMSG + 58;
constexpr UINT NPPM_GETBUFFERIDFROMPOS = NPPMSG + 59;
constexpr UINT NPPM_GETCURRENTBUFFERID = NPPMSG + 60;

constexpr WPARAM ALL_OPEN_FILES = 0;
constexpr LPARAM PRIMARY_VIEW = 1;
constexpr LPARAM SECOND_VIEW = 2;
constexpr int MAIN_VIEW = 0;
constexpr int SUB_VIEW = 1;

constexpr UINT SCI_GETLENGTH = 2006;
constexpr UINT SCI_SETSAVEPOINT = 2014;
constexpr UINT SCI_GETTEXT = 2182;

constexpr LPARAM IDM_FILE_CLOSE = 41003;

struct BufferInfo {
    uintptr_t id = 0;
    int preferredView = MAIN_VIEW;
    std::wstring titleOrPath;
};

NppData g_nppData;
FuncItem g_funcItems[kFuncCount];
bool g_menuInitialized = false;

LRESULT SendNpp(UINT message, WPARAM wParam = 0, LPARAM lParam = 0) {
    return ::SendMessageW(g_nppData._nppHandle, message, wParam, lParam);
}

HWND GetCurrentScintilla() {
    int which = -1;
    SendNpp(NPPM_GETCURRENTSCINTILLA, 0, reinterpret_cast<LPARAM>(&which));
    if (which == MAIN_VIEW) {
        return g_nppData._scintillaMainHandle;
    }
    if (which == SUB_VIEW) {
        return g_nppData._scintillaSecondHandle;
    }
    return nullptr;
}

bool SetCommand(size_t index, const wchar_t* name, PFUNCPLUGINCMD func, ShortcutKey* shortcut = nullptr, bool checked = false) {
    if (index >= static_cast<size_t>(kFuncCount) || !name || !func) {
        return false;
    }

    lstrcpynW(g_funcItems[index]._itemName, name, menuItemSize);
    g_funcItems[index]._pFunc = func;
    g_funcItems[index]._init2Check = checked;
    g_funcItems[index]._pShKey = shortcut;
    return true;
}

std::wstring GetFullPathFromBuffer(uintptr_t bufferId) {
    const auto length = SendNpp(NPPM_GETFULLPATHFROMBUFFERID, static_cast<WPARAM>(bufferId), 0);
    if (length <= 0) {
        return {};
    }

    std::wstring value(static_cast<size_t>(length) + 1, L'\0');
    SendNpp(NPPM_GETFULLPATHFROMBUFFERID, static_cast<WPARAM>(bufferId), reinterpret_cast<LPARAM>(value.data()));
    value.resize(wcslen(value.c_str()));
    return value;
}

bool IsUnsavedScratchBuffer(const std::wstring& titleOrPath) {
    if (titleOrPath.empty()) {
        return true;
    }

    std::error_code ec;
    const std::filesystem::path path(titleOrPath);
    return !path.is_absolute();
}

bool ActivateBuffer(uintptr_t bufferId, int preferredView) {
    const auto encoded = SendNpp(NPPM_GETPOSFROMBUFFERID, static_cast<WPARAM>(bufferId), preferredView);
    if (encoded == -1) {
        return false;
    }

    const int view = static_cast<int>((static_cast<uint32_t>(encoded) >> 30) & 0x3);
    const int index = static_cast<int>(static_cast<uint32_t>(encoded) & 0x3fffffffU);
    return SendNpp(NPPM_ACTIVATEDOC, view, index) != 0;
}

std::string WideToUtf8(const std::wstring& text) {
    if (text.empty()) {
        return {};
    }

    const int bytes = ::WideCharToMultiByte(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), nullptr, 0, nullptr, nullptr);
    if (bytes <= 0) {
        return {};
    }

    std::string utf8(static_cast<size_t>(bytes), '\0');
    ::WideCharToMultiByte(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), utf8.data(), bytes, nullptr, nullptr);
    return utf8;
}

std::string ReadActiveDocumentText() {
    const HWND scintilla = GetCurrentScintilla();
    if (!scintilla) {
        return {};
    }

    const auto length = static_cast<size_t>(::SendMessageW(scintilla, SCI_GETLENGTH, 0, 0));
    std::string text(length + 1, '\0');
    ::SendMessageA(scintilla, SCI_GETTEXT, static_cast<WPARAM>(length + 1), reinterpret_cast<LPARAM>(text.data()));
    text.resize(length);
    return text;
}

std::vector<BufferInfo> EnumerateUnsavedScratchBuffers() {
    std::vector<BufferInfo> buffers;

    for (const auto [view, countKind] : { std::pair{MAIN_VIEW, PRIMARY_VIEW}, std::pair{SUB_VIEW, SECOND_VIEW} }) {
        const auto count = static_cast<int>(SendNpp(NPPM_GETNBOPENFILES, 0, countKind));
        for (int i = 0; i < count; ++i) {
            const auto bufferId = static_cast<uintptr_t>(SendNpp(NPPM_GETBUFFERIDFROMPOS, static_cast<WPARAM>(i), view));
            if (bufferId == 0) {
                continue;
            }

            const auto titleOrPath = GetFullPathFromBuffer(bufferId);
            if (!IsUnsavedScratchBuffer(titleOrPath)) {
                continue;
            }

            buffers.push_back(BufferInfo{ bufferId, view, titleOrPath.empty() ? L"Untitled" : titleOrPath });
        }
    }

    return buffers;
}

std::wstring ChooseDumpPath() {
    wchar_t fileName[MAX_PATH] = L"dump.txt";
    OPENFILENAMEW ofn{};
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = g_nppData._nppHandle;
    ofn.lpstrFilter = L"Text files (*.txt)\0*.txt\0All files (*.*)\0*.*\0";
    ofn.lpstrFile = fileName;
    ofn.nMaxFile = MAX_PATH;
    ofn.lpstrDefExt = L"txt";
    ofn.Flags = OFN_OVERWRITEPROMPT | OFN_PATHMUSTEXIST;
    ofn.lpstrTitle = L"Save combined unsaved tabs as";

    return ::GetSaveFileNameW(&ofn) ? std::wstring(fileName) : std::wstring();
}

bool WriteDumpFile(const std::wstring& outputPath, const std::vector<BufferInfo>& buffers, std::wstring& error) {
    std::ofstream out(std::filesystem::path(outputPath), std::ios::binary | std::ios::trunc);
    if (!out) {
        error = L"Could not create the dump file.";
        return false;
    }

    const char bom[] = { char(0xEF), char(0xBB), char(0xBF) };
    out.write(bom, sizeof(bom));

    const auto originalBufferId = static_cast<uintptr_t>(SendNpp(NPPM_GETCURRENTBUFFERID, 0, 0));

    for (size_t i = 0; i < buffers.size(); ++i) {
        const auto& buffer = buffers[i];
        if (!ActivateBuffer(buffer.id, buffer.preferredView)) {
            error = L"Could not activate one of the unsaved tabs.";
            return false;
        }

        const auto header = std::string(
            "===== BEGIN TAB: " + WideToUtf8(buffer.titleOrPath) + " =====\r\n");
        out.write(header.data(), static_cast<std::streamsize>(header.size()));

        const auto text = ReadActiveDocumentText();
        if (!text.empty()) {
            out.write(text.data(), static_cast<std::streamsize>(text.size()));
        }

        if (text.empty() || (text.back() != '\n' && text.back() != '\r')) {
            out.write("\r\n", 2);
        }

        const auto footer = std::string("===== END TAB =====\r\n");
        out.write(footer.data(), static_cast<std::streamsize>(footer.size()));

        if (i + 1 < buffers.size()) {
            out.write("\r\n", 2);
        }
    }

    out.flush();
    if (!out) {
        error = L"Writing the dump file failed.";
        return false;
    }

    if (originalBufferId != 0) {
        ActivateBuffer(originalBufferId, MAIN_VIEW);
    }

    return true;
}

void CloseBuffersWithoutSaving(const std::vector<BufferInfo>& buffers) {
    for (const auto& buffer : buffers) {
        if (!ActivateBuffer(buffer.id, buffer.preferredView)) {
            continue;
        }

        if (const HWND scintilla = GetCurrentScintilla()) {
            ::SendMessageW(scintilla, SCI_SETSAVEPOINT, 0, 0);
        }

        SendNpp(NPPM_MENUCOMMAND, 0, IDM_FILE_CLOSE);
    }
}

void ShowMessageBox(const std::wstring& text, UINT flags = MB_OK | MB_ICONINFORMATION) {
    ::MessageBoxW(g_nppData._nppHandle, text.c_str(), kPluginName, flags);
}

void DumpUnsavedTabsToFileAndClose() {
    const auto buffers = EnumerateUnsavedScratchBuffers();
    if (buffers.empty()) {
        ShowMessageBox(L"No unsaved scratch tabs were found.");
        return;
    }

    const auto outputPath = ChooseDumpPath();
    if (outputPath.empty()) {
        return;
    }

    std::wstring error;
    if (!WriteDumpFile(outputPath, buffers, error)) {
        ShowMessageBox(error.empty() ? L"The dump file could not be written." : error, MB_OK | MB_ICONERROR);
        return;
    }

    CloseBuffersWithoutSaving(buffers);

    std::wstring message = L"Dumped ";
    message += std::to_wstring(buffers.size());
    message += L" unsaved tab(s) to:\n\n";
    message += outputPath;
    ShowMessageBox(message);
}

void InitializeMenu() {
    if (g_menuInitialized) {
        return;
    }

    SetCommand(0, L"Dump unsaved tabs to dump.txt and close", &DumpUnsavedTabsToFileAndClose);
    g_menuInitialized = true;
}
} // namespace

extern "C" __declspec(dllexport) void setInfo(NppData data) {
    g_nppData = data;
    InitializeMenu();
}

extern "C" __declspec(dllexport) const wchar_t* getName() {
    return kPluginName;
}

extern "C" __declspec(dllexport) FuncItem* getFuncsArray(int* count) {
    InitializeMenu();
    if (count) {
        *count = kFuncCount;
    }
    return g_funcItems;
}

extern "C" __declspec(dllexport) void beNotified(SCNotification*) {
}

extern "C" __declspec(dllexport) LRESULT messageProc(UINT, WPARAM, LPARAM) {
    return TRUE;
}

extern "C" __declspec(dllexport) BOOL isUnicode() {
    return TRUE;
}
