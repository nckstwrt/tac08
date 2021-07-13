#include "hal_fs.h"

#ifdef _WIN32
#include "../win-tac08/dirent.h"
#include <filesystem>
void getcwd(char *buf, int max) 
{
	strcpy(buf, std::filesystem::current_path().generic_string().c_str());
}
void chdir(const char *szDir) 
{
	SetCurrentDirectoryA(szDir);
}
#else
#include <dirent.h>
#include <unistd.h>
#endif

#include <sys/stat.h>
#include <sys/types.h>


namespace hal_fs {
	std::string cwd() {
	    char buf[PATH_MAX+1];
		getcwd(buf, PATH_MAX);
		std::string val(buf);
		return val;
	}

	finfo files() {
		static DIR* dir_ptr = nullptr;

		if (!dir_ptr) {
			dir_ptr = opendir(cwd().c_str());
		}

		finfo fi = {};
		if (dir_ptr) {
			auto entry = readdir(dir_ptr);
			if (entry) {
				fi.name = entry->d_name;
				fi.dir = entry->d_type == DT_DIR;
				return fi;
			} else {
				closedir(dir_ptr);
				dir_ptr = nullptr;
			}
		}
		return fi;
	}

	void cd(const char* dir) {
		chdir(dir);
	}

	/*
	    // read / write from anywhere
	    std::string loadFile(std::string name);
	    bool saveFile(std::string name, std::string data);

	    // read / write from default game save file dir
	    std::string loadGameState(std::string name);
	    void saveGameState(std::string name, std::string data);

	    // read / write from clip board
	    std::string readClip();
	    void writeClip(const std::string& data);
	*/

}  // namespace hal_fs