const fs = require('fs');
const path = require('path');

class StudentModel{
    constructor(){
        this.filePath = path.join(__dirname,'Students.json');
        this.students = this.loadStudents();
        this.idCounter= this.students.length?Math.max(...this.students.map(s=>s.id))+1:1;
    }


    loadStudents(){
        if(fs.existsSync(this.filePath)){
            try{
                const data = fs.readFileSync(this.filePath,'utf-8');
                return JSON.parse(data);
            }
            catch(err){
                console.error("Failed to load data from Students.json. Error: ",err);
                return [];
            }
        }
        return [];
    }

    saveStudents(){
        try{
            fs.writeFileSync(this.filePath,JSON.stringify(this.students,null,2));
        }
        catch(err){
            console.error("Failed to save data to Students.json. Error: ",err);
        }
    }

    getAll(){
        return this.students;
    }

    getById(id){
        return this.students.find(s=>s.id==Number(id))||null;
    }

    create(data){
        const newStudent = {
            id:this.idCounter++,
            name:data.name,
            age:data.age||null,
            major:data.major
        };

        this.students.push(newStudent);
        this.saveStudents();
        return newStudent;
    }

    update(id,data){
        const studentIndex = this.students.findIndex(s=>s.id==Number(id));
        if(studentIndex==-1){
            return null;
        }

        this.students[studentIndex] = {...this.students[studentIndex],...data};
        this.saveStudents();
        return this.students[studentIndex];
    }

    delete(id){
        const studentIndex = this.students.findIndex(s=>s.id==Number(id));
        if(studentIndex==-1){
            return false;
        }
        this.students.splice(studentIndex,1);
        this.saveStudents();
        return true;
    }
}


module.exports = new StudentModel();