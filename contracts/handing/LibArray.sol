pragma solidity ^0.6.0;

library LibArray {

    function addValue(uint256[][] storage array,uint256[] memory value) internal{
        require(value.length > 0, "Empty Array: can not add empty array");
        array.push(value);
    }

    function getValue(uint256[][] storage array, uint256 row, uint256 col) internal view returns (uint256) {
        if(array.length == 0){
            return 0;
        }
        require(row < array.length,"Row: index out of bounds");
        require(col < array[row].length, "Col: index out of bounds");
        return array[row][col];
    }

    function setValue(uint256[][] storage array, uint256 row, uint256 col, uint256 val) internal returns (uint256[][] memory) {
        if(array.length == 0){
            return array;
        }

        require(row < array.length,"Row: index out of bounds");
        require(col < array[row].length, "Col: index out of bounds");
        array[row][col] = val;
        return array;
    }

    function firstIndexOf(uint256[][] storage array, uint256 val) internal view returns (bool, uint256, uint256) {
        uint256  row;
        uint256  col;
        if (array.length == 0) {
            return (false, 0, 0);
        }
        for(uint256 i = 0; i < array.length; i++) {
            for(uint256 j = 0; j < array[i].length; j++) {
                if(array[i][j] == val){
                    row = i;
                    col = j;
                    return (true, row, col);
                }
            }
        }
        return (false, 0, 0);
    }

    function removeByIndex(uint256[][] storage array, uint256 index) internal returns(uint256[][] memory) {
        require(index < array.length, "Index: index out of bounds");
        delete array[index];

        while(index < array.length -1) {
            delete array[index];
            for(uint256 i = 0; i < array[index + 1].length; i++){
                array[index].push(array[index + 1][i]);
            }
            index++;
        }
        array.pop();
        return array;
    }

    function extend(uint256[][] storage array1, uint256[][] storage array2) internal returns(uint256[][] memory){
        require(array2.length > 0, "Extend: can not extend empty array");

        for(uint256 i = 0; i < array2.length; i++){
            array1.push(array2[i]);
        }
        return array1;
    }
}
