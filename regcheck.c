#include <windows.h>


static HKEY reg_open_key(const HKEY base, const char *keypath, int perm)
{
	HKEY key;
	DWORD dwType, dwSize;
	int len;
	char val[256] = { '\0' }, path[1024] = { '\0' }, *ptr;

	if (ptr = strrchr(keypath, '/')) {
		len = (int)(ptr - keypath);
		if (len > 1024) len = 1024;
		strncpy(path, keypath, len);
		strncpy(val, ptr + 1, 256);
		ptr = path;
		while (*++ptr != '\0')
		{
			if (*ptr == '/') *ptr = '\\';
		}
	}
	else if (ptr = strrchr(keypath, '\\')) {
		len = (int)(ptr - keypath);
		if (len > 1024) len = 1024;
		strncpy(path, keypath, len);
		strncpy(val, ptr + 1, 256);
	}
	RegOpenKeyEx(base, path, 0, perm, &key);
	return key;
}

char *reg_get_value(const HKEY base, const char *keypath)
{
	HKEY key;
	DWORD dwType, dwSize;
	int len;
	char val[256], path[1024], *ptr;

	memset(val, '\0', 256);
	memset(path, '\0', 1024);

	key = reg_open_key(HKEY_LOCAL_MACHINE, keypath, KEY_READ);
	if (RegQueryValueEx(key, val, NULL, &dwType, NULL, &dwSize) != ERROR_SUCCESS) {
		RegCloseKey(key);
		return NULL;
	}
	ptr = malloc(dwSize);
	if (!ptr) {
		RegCloseKey(key);
		return NULL;
	}
	if (RegQueryValueEx(key, val, NULL, &dwType, ptr, &dwSize) != ERROR_SUCCESS) {
		RegCloseKey(key);
		free(ptr);
		return NULL;
	}
	RegCloseKey(key);
	return ptr;
}

int reg_set_value(const HKEY base, const char *keypath, const char *newvalue)
{
	HKEY key;
	DWORD dwType, dwSize;
	int len;
	char *val, *path, buffer[1024] = { '\0' };

	strncpy(buffer, keypath, 1024);
	if ( !(val = strrchr(buffer, '\\')) )
		val = strrchr(buffer, '/');
	if (!*++val)
		val = NULL;

	key = reg_open_key(base, keypath, KEY_WRITE);
	if (RegSetValue(key, val, REG_SZ, newvalue, strlen(newvalue)) != ERROR_SUCCESS) {
		perror("RegSetValue");
		RegCloseKey(key);
		return errno;
	}
	RegCloseKey(key);
	return 0;
}
