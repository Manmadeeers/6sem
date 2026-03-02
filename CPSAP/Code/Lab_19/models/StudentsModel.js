const fs = require('fs');
const path= require('path');

class StudentsModel{
    constructor(){
        this.file_path = path.join(__dirname,'..','StudentsList.json');
        this.students = this.loadStudents();
        this.students_counter = this.students.length?Math.max(...this.students.map(s=>s.id))+1:1;
    }

    loadStudents(){
        try{
            const raw = fs.readFileSync(this.file_path,'utf8');
            return JSON.parse(raw);
        }
        catch(err){
            console.error("Failed parsing data from StudentsList.json");
            return [];
        }
    }

    saveStudents(){
        try{
            fs.writeFileSync(this.file_path,JSON.stringify(this.students,null,2))
        }
        catch(err){
            console.error("Failed to save data to StudentsList.json");
        }
    }

    getAllStudents(){
        return this.students;
    }
    
    getStudentById(id){
        return this.students.find(s=>s.id==id);
    }

    createStudent(data){
        const newStudent = {
            id:this.students_counter++,
            name:data.name,
            age:data.age,
            major:data.major
        }
        
        this.students.push(newStudent);
        this.saveStudents();
        return newStudent;
    }

    updateStudent(id,data){
        const foundIndex = this.students.findIndex(s=>s.id==id);
        if(foundIndex!=-1){
            this.students[foundIndex] = {...this.students[foundIndex],...data};
            this.saveStudents();
            return this.students[foundIndex];
        }
        else{
            return null;
        }
    }

    removeStudent(id){
        const foundIndex  =this.students.findIndex(s=>s.id==id);
        if(foundIndex!=-1){
            this.students.splice(foundIndex,1);
            this.saveStudents();
            return true;
        }
        else{
            return false;
        }
    }
}


module.exports = new StudentsModel();