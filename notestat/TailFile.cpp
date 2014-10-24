#include "TailFile.h"

TailFile::TailFile() : blockSize_(256) {} 
TailFile::TailFile(string file) : file_(file), fs_(file_.c_str(), ifstream::in), blockSize_(256) {

        if(!fs_) {

            throw "Unable to open file: " + file;

        }


        fs_.seekg (0, ios::end);
        pos_ = fs_.tellg();
		//cout << "\nDEBUG: TailFile: pos_ is " << pos_ << endl;;

        buf_ = new char[blockSize_+1];
		//cout << "\nDEBUG: TailFile: pos_ is " << pos_ << endl;;

}

bool TailFile::getLine(string &line) {


		//cout << "\nDEBUG: Into getLine\n";
		//cout << "\nDEBUG: getLine : pos_ is " << pos_ << endl;;

        if(lineCache_.empty()) {

            bufferLines();
            if(lineCache_.empty()) { return false;}

        }

        line = lineCache_.top();
        lineCache_.pop();

        return true;

}

void TailFile::bufferLines() {

		//cout << "\nDEBUG: Into bufferLines: pos_ is " << pos_ << endl;;

        // Nothing to read
        if(pos_ == streampos(0)) { return; }

        if(pos_ < blockSize_) {

            blockSize_ = pos_;
            pos_ = 0;

        }
        else {

            pos_ -= blockSize_;

        }

		//cout << "\nDEBUG: bufferLines: pos_ is " << pos_ << endl;;

        fs_.seekg((-1)*blockSize_, ios::cur);
        fs_.read(buf_, blockSize_);
        int n = fs_.gcount();
        buf_[n] = '\0';
		//cout << "\nDEBUG: bufferLines:: read buffer of size " << n << endl;

        if(n == 0) { return; }

        // Ignore the partial line in the beginning.
        int i = 0;
        while(buf_[i++] != '\n');

        fs_.seekg((-1)*blockSize_ + i, ios::cur);

        // Move lines to cache
        while(buf_[i] != '\0') {

            char *ch1 = buf_ + i;
            char *ch2 = strchr(buf_+i, '\n');
			// The last line may not be complete. Ignore it.
			if(ch2 == NULL) { break; }
            *ch2 = '\0';
            // Move to next line
            i += ch2 - ch1 + 1;
            lineCache_.push(ch1);
			//cout << "\nDEBUG: bufferLines:: stored line " << ch1 << endl;


        }



}
