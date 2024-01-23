#include <Windows.h>
int main() {
	HMODULE kernel32 = GetModuleHandleW(L"KERNEL32.dll");
	GetProcAddress(kernel32, "LoadLibraryA");
	MessageBoxA(0, 0, 0, 0);
}